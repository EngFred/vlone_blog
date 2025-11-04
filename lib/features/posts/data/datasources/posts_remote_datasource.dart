import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/core/utils/media_dimensions_util.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';
import 'package:workmanager/workmanager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vlone_blog_app/core/utils/video_compressor.dart';
import 'package:vlone_blog_app/core/utils/image_compressor.dart';
import 'package:vlone_blog_app/core/utils/media_progress_notifier.dart';

class PostsRemoteDataSource {
  final SupabaseClient client;
  // Store channel references for cleanup
  RealtimeChannel? _postsUpdatesChannel;
  RealtimeChannel? _postDeletionsChannel;
  RealtimeChannel? _postsInsertsChannel;
  // Stream controllers (single broadcast controllers reused by callers)
  StreamController<Map<String, dynamic>>? _postsController;
  StreamController<String>? _postDeletionsController;
  StreamController<PostModel>? _newPostsController;

  /// Client-side batch and debounce tuning
  static const int _maxBatchSize = 50; // maximum IDs per batch RPC
  static const Duration _coalesceWindow = Duration(milliseconds: 300);
  static const int _rpcMaxAttempts = 3;

  PostsRemoteDataSource(this.client);

  // =========================================================================
  // Non-Blocking Post Creation
  // This logic now correctly uses the 'upload_status' column.
  // =========================================================================
  Future<PostModel> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    AppLogger.info('Attempting to create post for user: $userId');

    // --- 1. Pre-processing (Compression & Validation) ---
    File? fileToProcess;
    int? mediaWidth;
    int? mediaHeight;

    if (mediaFile != null) {
      fileToProcess = mediaFile;
      try {
        // --- Duration Check (Fail Fast) ---
        if (mediaType == 'video') {
          try {
            final duration = await getVideoDuration(fileToProcess);
            if (duration > Constants.maxVideoDurationSeconds) {
              AppLogger.warning(
                'createPost: video duration $duration exceeds limit.',
              );
              throw const ServerException('Video exceeds allowed duration');
            }
          } catch (e) {
            AppLogger.warning('createPost: getVideoDuration probe failed: $e');
            // Allow proceeding; compressor will re-check
          }
        }

        // --- Compression ---
        bool shouldAttemptCompression = true;
        try {
          final bytes = await fileToProcess.length();
          final threshold = mediaType == 'video'
              ? VideoCompressor.defaultMinSizeBytes
              : ImageCompressor.defaultMaxSizeBytes;
          shouldAttemptCompression = bytes > threshold;
        } catch (e) {
          AppLogger.warning('createPost: failed to stat file size: $e');
        }

        if (shouldAttemptCompression) {
          File? compressedFile;
          if (mediaType == 'video') {
            MediaProgressNotifier.notifyCompressing(0.0);
            compressedFile = await VideoCompressor.compressIfNeeded(
              fileToProcess,
              onProgress: MediaProgressNotifier.notifyCompressing,
            );
          } else if (mediaType == 'image') {
            compressedFile = await ImageCompressor.compressIfNeeded(
              fileToProcess,
            );
          }

          if (compressedFile != null &&
              compressedFile.path != fileToProcess.path) {
            AppLogger.info(
              'createPost: using compressed $mediaType at ${compressedFile.path}',
            );
            fileToProcess = compressedFile;
          }
        }

        // --- Get Dimensions ---
        // Probe *after* compression/trimming
        final dimensions = await getMediaDimensions(fileToProcess, mediaType!);
        mediaWidth = dimensions?.width;
        mediaHeight = dimensions?.height;

        // --- Final Duration Safety Check ---
        if (mediaType == 'video') {
          try {
            final duration = await getVideoDuration(fileToProcess);
            if (duration > Constants.maxVideoDurationSeconds) {
              throw const ServerException('Video exceeds allowed duration');
            }
          } catch (e) {
            AppLogger.warning(
              'createPost: duration probe failed after compression: $e',
            );
          }
        }
      } catch (e) {
        AppLogger.error('Pre-processing failed: $e', error: e);
        MediaProgressNotifier.notifyError(e.toString());
        throw ServerException(e.toString());
      }
    }

    // --- 2. Create Post Record in Database ---
    try {
      final postData = {
        'user_id': userId,
        'content': content,
        'media_type': mediaType ?? 'none',
        'media_width': mediaWidth,
        'media_height': mediaHeight,
        // 🌟 Use the 'upload_status' column
        'upload_status': fileToProcess != null ? 'processing' : 'none',
        // media_url and thumbnail_url are null by default
      };

      final response = await client
          .from('posts')
          .insert(postData)
          .select('*, profiles ( username, profile_image_url )')
          .single();

      AppLogger.info(
        'Post record created successfully with ID: ${response['id']}',
      );

      // Inject default status fields for immediate UI use
      final postMap = response;
      postMap['is_liked'] = false;
      postMap['is_favorited'] = false;
      // The 'upload_status' is already in the map from the .select()

      final newPost = PostModel.fromMap(postMap);

      // --- 3. Fire-and-Forget Media Processing ---
      if (fileToProcess != null) {
        _handleMediaProcessing(
          postId: newPost.id,
          userId: userId,
          mediaFile: fileToProcess,
          mediaType: mediaType!,
        );
        MediaProgressNotifier.notifyUploading(0.0);
      } else {
        MediaProgressNotifier.notifyDone();
      }

      // --- 4. Return Initial Post Model ---
      return newPost;
    } catch (e, st) {
      AppLogger.error(
        'Error creating post record: $e',
        error: e,
        stackTrace: st,
      );
      MediaProgressNotifier.notifyError(e.toString());
      throw ServerException(e.toString());
    }
  }

  /// [Private Helper] Handles all blocking I/O for media.
  Future<void> _handleMediaProcessing({
    required String postId,
    required String userId,
    required File mediaFile,
    required String mediaType,
  }) async {
    // Generate unique file path *once*
    final fileExt = mediaFile.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';
    final mediaUploadPath = 'posts/media/$userId/$fileName';
    String? mediaUrl;
    String? thumbnailUrl;

    try {
      // --- 1. Upload Main Media ---
      mediaUrl = await _uploadFileToStorage(
        file: mediaFile,
        uploadPath: mediaUploadPath,
      );

      // --- 2. Generate & Upload Thumbnail (for video) ---
      if (mediaType == 'video') {
        final thumbFile = await _generateThumbnailFile(mediaFile);
        if (thumbFile != null) {
          final thumbExt = thumbFile.path.split('.').last;
          final thumbFileName = '${const Uuid().v4()}.$thumbExt';
          final thumbUploadPath = 'posts/thumbnails/$userId/$thumbFileName';

          thumbnailUrl = await _uploadFileToStorage(
            file: thumbFile,
            uploadPath: thumbUploadPath,
          );
          // Clean up local temp thumbnail
          try {
            await thumbFile.delete();
          } catch (_) {}
        }
      }

      // --- 3. Update Post with URLs & 'completed' status ---
      await client
          .from('posts')
          .update({
            'media_url': mediaUrl,
            'thumbnail_url': thumbnailUrl,
            'upload_status': 'completed',
          })
          .eq('id', postId);

      AppLogger.info('Media processing complete for post: $postId');
      MediaProgressNotifier.notifyDone();
    } catch (e, st) {
      AppLogger.error(
        'Media processing failed for post: $postId. Scheduling background retry.',
        error: e,
        stackTrace: st,
      );
      MediaProgressNotifier.notifyError(
        'Upload failed, will retry in background.',
      );

      // --- 4. Schedule Background Retry (Workmanager) ---
      String? localCopyPath;
      try {
        // Copy file to a persistent temp location for the worker
        final tempDir = await getTemporaryDirectory();
        localCopyPath = '${tempDir.path}/$fileName';
        await mediaFile.copy(localCopyPath);

        // Schedule the worker
        Workmanager().registerOneOffTask(
          'upload_post_media_$postId',
          'upload_post_media_task', // Name of your task in main.dart
          inputData: {
            'postId': postId,
            'userId': userId,
            'mediaType': mediaType,
            'filePath': localCopyPath,
            'mediaUploadPath': mediaUploadPath,
          },
        );

        // Update post status to 'pending_retry'
        await client
            .from('posts')
            .update({'upload_status': 'pending_retry'})
            .eq('id', postId);
      } catch (copyError) {
        AppLogger.error(
          'Failed to schedule background retry for post $postId: $copyError',
          error: copyError,
        );
        // Mark as failed if we can't even schedule the retry
        await client
            .from('posts')
            .update({'upload_status': 'failed'})
            .eq('id', postId);
      }
    }
  }

  /// [Private Helper] A simple, "do-or-die" uploader.
  Future<String> _uploadFileToStorage({
    required File file,
    required String uploadPath,
  }) async {
    try {
      final fileSize = await file.length();
      AppLogger.info(
        'Uploading file to path: $uploadPath (size=${fileSize} bytes)',
      );

      await client.storage.from('posts').upload(uploadPath, file);
      final url = client.storage.from('posts').getPublicUrl(uploadPath);

      AppLogger.info('File uploaded successfully, url: $url');
      return url;
    } catch (e, st) {
      AppLogger.error(
        'Upload failed for path: $uploadPath',
        error: e,
        stackTrace: st,
      );
      // Re-throw to be caught by _handleMediaProcessing
      throw ServerException('File upload failed: $e');
    }
  }

  /// [Private Helper] Generates a thumbnail file.
  Future<File?> _generateThumbnailFile(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxHeight: 720,
      );

      if (thumbPath == null) {
        throw Exception('Thumbnail generation returned null');
      }
      AppLogger.info('Thumbnail generated at: $thumbPath');
      return File(thumbPath);
    } catch (e, st) {
      AppLogger.error(
        'Thumbnail generation failed: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ------------------ RPC helpers ------------------
  List _normalizeRpcList(dynamic resp) {
    if (resp == null) return <dynamic>[];
    if (resp is List) return resp;
    if (resp is Map) return [resp];
    return <dynamic>[];
  }

  Future<dynamic> _callRpcWithRetry(
    String name, {
    Map<String, dynamic>? params,
  }) async {
    int attempt = 0;
    int delayMs = 200;
    while (true) {
      try {
        attempt++;
        if (params != null) {
          return await client.rpc(name, params: params);
        } else {
          return await client.rpc(name);
        }
      } catch (e) {
        if (attempt >= _rpcMaxAttempts) rethrow;
        AppLogger.warning(
          'RPC $name failed on attempt $attempt: $e — retrying in ${delayMs}ms',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2; // exponential backoff
      }
    }
  }

  // ==================== RPC for Feed Retrieval ====================
  // These methods will now receive the 'upload_status' from the RPCs
  // and pass it to the PostModel.
  // ================================================================
  Future<List<PostModel>> getFeed({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final response = await _callRpcWithRetry(
        'get_feed_with_user_status',
        params: {
          'current_user_id': currentUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );
      final rows = _normalizeRpcList(response);
      if (rows.isEmpty) return [];
      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching feed via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getReels({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final response = await _callRpcWithRetry(
        'get_posts_with_user_status',
        params: {
          'p_current_user_id': currentUserId,
          'p_media_type': 'video',
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );
      final rows = _normalizeRpcList(response);
      if (rows.isEmpty) return [];
      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching reels via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final response = await _callRpcWithRetry(
        'get_posts_with_user_status',
        params: {
          'p_current_user_id': currentUserId,
          'p_post_user_id': profileUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );
      final rows = _normalizeRpcList(response);
      if (rows.isEmpty) return [];
      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching user posts via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<PostModel> getPost({
    required String postId,
    required String currentUserId,
  }) async {
    try {
      final response = await _callRpcWithRetry(
        'get_post_with_profile',
        params: {'p_post_id': postId, 'p_current_user_id': currentUserId},
      );
      final rows = _normalizeRpcList(response);
      if (rows.isNotEmpty) {
        return PostModel.fromMap(rows.first as Map<String, dynamic>);
      } else {
        AppLogger.error('No post found for ID: $postId');
        throw const ServerException('Post not found or unauthorized');
      }
    } catch (e) {
      AppLogger.error('Error fetching post $postId: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  // ==================== Share Count (FIXED) ====================
  Future<void> sharePost({required String postId}) async {
    try {
      AppLogger.info('Attempting to share post: $postId');
      final shareUrl = 'Check this post: https://myapp.com/post/$postId';

      // ⚠️ FIX: Use shareWithResult from the 'share_plus' package
      final result = await Share.share(shareUrl);

      // Only increment the count if the share was successful.
      if (result.status == ShareResultStatus.success) {
        AppLogger.info('Post shared, incrementing count via RPC...');
        await _callRpcWithRetry(
          'increment_post_shares',
          params: {'post_id_param': postId},
        );
        AppLogger.info('Post shared and count updated successfully via RPC');
      } else {
        AppLogger.info('Share dialog dismissed, not incrementing count.');
      }
    } catch (e) {
      AppLogger.error('Error sharing post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      AppLogger.info('Attempting to delete post: $postId');
      // Note: RLS will handle authorization.
      // We must also handle media deletion (e.g., via Storage triggers)
      await client.from('posts').delete().eq('id', postId);
      AppLogger.info('Post deleted successfully: $postId');
    } catch (e) {
      AppLogger.error('Error deleting post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  // ==================== Realtime streams ====================

  /// Stream for new posts being created.
  Stream<PostModel> streamNewPosts() {
    AppLogger.info('Setting up real-time stream for new posts (coalesced)');

    // --- INJECTED: use current logged-in Supabase user id from the provided client
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      AppLogger.warning(
        'streamNewPosts: no authenticated user found; returning empty stream',
      );
      return Stream<PostModel>.empty();
    }

    if (_newPostsController != null && !_newPostsController!.isClosed) {
      return _newPostsController!.stream;
    }
    _newPostsController = StreamController<PostModel>.broadcast();
    final channel = client.channel('realtime:posts:inserts');
    _postsInsertsChannel = channel;

    final List<String> idBuffer = [];
    Timer? flushTimer;
    bool isFlushing = false;

    Future<void> flushIds() async {
      if (isFlushing) return;
      isFlushing = true;
      final ids = List<String>.from(idBuffer);
      idBuffer.clear();
      flushTimer = null;
      if (ids.isEmpty) {
        isFlushing = false;
        return;
      }

      for (int i = 0; i < ids.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < ids.length)
            ? i + _maxBatchSize
            : ids.length;
        final chunk = ids.sublist(i, end);
        try {
          final batchResponse = await _callRpcWithRetry(
            'get_posts_batch',
            params: {'p_post_ids': chunk, 'p_current_user_id': currentUserId},
          );
          final rows = _normalizeRpcList(batchResponse);
          for (final r in rows) {
            try {
              final map = r as Map<String, dynamic>;
              if (!(_newPostsController?.isClosed ?? true)) {
                _newPostsController!.add(PostModel.fromMap(map));
              }
            } catch (e, st) {
              AppLogger.error(
                'Error parsing batched post map: $e',
                error: e,
                stackTrace: st,
              );
            }
          }
        } catch (e) {
          AppLogger.warning(
            'Batch RPC failed, falling back to per-id fetch: $e',
          );
          for (final id in chunk) {
            try {
              final resp = await _callRpcWithRetry(
                'get_post_with_profile',
                params: {'p_post_id': id, 'p_current_user_id': currentUserId},
              );
              final rows = _normalizeRpcList(resp);
              if (rows.isNotEmpty) {
                final map = rows.first as Map<String, dynamic>;
                if (!(_newPostsController?.isClosed ?? true)) {
                  _newPostsController!.add(PostModel.fromMap(map));
                }
              }
            } catch (e2) {
              AppLogger.error(
                'Failed to fetch post $id during fallback: $e2',
                error: e2,
              );
            }
          }
        }
      }
      isFlushing = false;
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              final newRec = payload.newRecord;
              final id = (newRec['id'] ?? '') as String;
              if (id.isEmpty) return;
              idBuffer.add(id);
              if (idBuffer.length >= _maxBatchSize) {
                flushTimer?.cancel();
                flushTimer = null;
                unawaited(flushIds());
                return;
              }
              flushTimer ??= Timer(_coalesceWindow, () {
                unawaited(flushIds());
              });
            } catch (e, st) {
              AppLogger.error(
                'Error handling new post payload: $e',
                error: e,
                stackTrace: st,
              );
            }
          },
        )
        .subscribe();

    _newPostsController!.onCancel = () async {
      try {
        flushTimer?.cancel();
        await flushIds(); // Flush any remaining IDs
        if (!(_newPostsController?.hasListener ?? false)) {
          await _postsInsertsChannel?.unsubscribe();
          _postsInsertsChannel = null;
          if (!(_newPostsController?.isClosed ?? true)) {
            await _newPostsController?.close();
          }
          _newPostsController = null;
        }
      } catch (e) {
        AppLogger.warning('Error cleaning up new posts stream: $e');
      }
    };
    return _newPostsController!.stream;
  }

  /// Stream for post updates (likes_count, comments_count, etc.)
  Stream<Map<String, dynamic>> streamPostUpdates() {
    AppLogger.info('Setting up real-time stream for post updates');
    if (_postsController != null && !_postsController!.isClosed) {
      return _postsController!.stream;
    }
    _postsController = StreamController<Map<String, dynamic>>.broadcast();
    final channel = client.channel('realtime:posts:updates');
    _postsUpdatesChannel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              final newRec = payload.newRecord;
              final id = newRec['id'] as String?;
              if (id == null) return;
              // Also pass upload_status for UI updates
              final data = {
                'id': id,
                'likes_count': newRec['likes_count'],
                'comments_count': newRec['comments_count'],
                'favorites_count': newRec['favorites_count'],
                'shares_count': newRec['shares_count'],
                'upload_status': newRec['upload_status'], // 🌟 Pass status
                'media_url': newRec['media_url'], // 🌟 Pass URLs
                'thumbnail_url': newRec['thumbnail_url'],
              };
              if (!(_postsController?.isClosed ?? true)) {
                _postsController!.add(Map<String, dynamic>.from(data));
              }
            } catch (e, st) {
              AppLogger.error(
                'Error handling post update payload: $e',
                error: e,
                stackTrace: st,
              );
            }
          },
        )
        .subscribe();

    _postsController!.onCancel = () async {
      try {
        if (!(_postsController?.hasListener ?? false)) {
          await _postsUpdatesChannel?.unsubscribe();
          _postsUpdatesChannel = null;
          if (!(_postsController?.isClosed ?? true)) {
            await _postsController?.close();
          }
          _postsController = null;
          AppLogger.info('Posts updates stream cancelled and cleaned up');
        }
      } catch (e) {
        AppLogger.warning('Error cancelling posts updates stream: $e');
      }
    };
    return _postsController!.stream;
  }

  /// Stream for post deletions
  Stream<String> streamPostDeletions() {
    AppLogger.info('Setting up real-time stream for post deletions');
    if (_postDeletionsController != null &&
        !_postDeletionsController!.isClosed) {
      return _postDeletionsController!.stream;
    }
    _postDeletionsController = StreamController<String>.broadcast();
    final channel = client.channel('realtime:posts:deletions');
    _postDeletionsChannel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              final deletedPostId = payload.oldRecord['id'] as String?;
              if (deletedPostId == null) return;
              if (!(_postDeletionsController?.isClosed ?? true)) {
                _postDeletionsController!.add(deletedPostId);
              }
            } catch (e, st) {
              AppLogger.error(
                'Error handling post deletion payload: $e',
                error: e,
                stackTrace: st,
              );
            }
          },
        )
        .subscribe();

    _postDeletionsController!.onCancel = () async {
      try {
        if (!(_postDeletionsController?.hasListener ?? false)) {
          await _postDeletionsChannel?.unsubscribe();
          _postDeletionsChannel = null;
          if (!(_postDeletionsController?.isClosed ?? true)) {
            await _postDeletionsController?.close();
          }
          _postDeletionsController = null;
          AppLogger.info('Post deletions stream cancelled and cleaned up');
        }
      } catch (e) {
        AppLogger.warning('Error cancelling post deletions stream: $e');
      }
    };
    return _postDeletionsController!.stream;
  }

  /// Cleanup method to unsubscribe from all channels
  void dispose() {
    AppLogger.info('Disposing PostsRemoteDataSource - cleaning up channels');
    try {
      _postsUpdatesChannel?.unsubscribe();
    } catch (_) {}
    try {
      _postDeletionsChannel?.unsubscribe();
    } catch (_) {}
    try {
      _postsInsertsChannel?.unsubscribe();
    } catch (_) {}
    try {
      _postsController?.close();
    } catch (_) {}
    try {
      _postDeletionsController?.close();
    } catch (_) {}
    try {
      _newPostsController?.close();
    } catch (_) {}
  }
}
