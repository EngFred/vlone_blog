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
  // 1. `createPost` (Called by the UI) - UPDATED WITH STRICT SIZE LIMITS
  // =========================================================================
  Future<void> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    AppLogger.info('Creating post for user: $userId');

    File? fileToProcess = mediaFile;
    String? mediaFileExt = mediaFile?.path.split('.').last;

    try {
      // --- 1. Pre-processing (Compression, Validation) ---
      int? mediaWidth;
      int? mediaHeight;

      if (fileToProcess != null && mediaType != null) {
        // --- Initial Size Check (Fail Fast) ---
        final initialBytes = await fileToProcess.length();
        final maxSize = mediaType == 'video'
            ? Constants.maxVideoSizeBytes
            : Constants.maxImageSizeBytes;

        AppLogger.info(
          'Initial file size: $initialBytes bytes, Max allowed: $maxSize bytes',
        );

        // CRITICAL: Check if file is too large even before compression
        if (initialBytes > maxSize) {
          AppLogger.warning(
            'File exceeds maximum size limit before compression: $initialBytes bytes',
          );
          // Still attempt compression - it might reduce the size enough
        }

        // --- Duration Check (Fail Fast) ---
        if (mediaType == 'video') {
          try {
            final duration = await getVideoDuration(fileToProcess);
            if (duration > Constants.maxVideoDurationSeconds) {
              AppLogger.error(
                'Video duration exceeds limit: $duration seconds',
              );
              MediaProgressNotifier.notifyError(
                'Video duration exceeds 1 minute limit',
              );
              throw ServerException('Video duration exceeds 1 minute limit');
            }
          } catch (e) {
            AppLogger.warning('getVideoDuration probe failed: $e');
          }
        }

        // --- Compression ---
        bool shouldAttemptCompression = true;
        try {
          // **OPTIMIZATION**: Re-use 'initialBytes' instead of reading file length again
          final threshold = mediaType == 'video'
              ? VideoCompressor.defaultMinSizeBytes
              : ImageCompressor.defaultMaxSizeBytes;
          shouldAttemptCompression = initialBytes > threshold;
        } catch (e) {
          AppLogger.warning('Failed to stat file size: $e');
        }

        if (shouldAttemptCompression) {
          MediaProgressNotifier.notifyCompressing(0.0);
          File? compressedFile;
          if (mediaType == 'video') {
            compressedFile = await VideoCompressor.compressIfNeeded(
              fileToProcess,
              onProgress: (percent) =>
                  MediaProgressNotifier.notifyCompressing(percent),
            );
          } else if (mediaType == 'image') {
            compressedFile = await ImageCompressor.compressIfNeeded(
              fileToProcess,
              onProgress: (percent) =>
                  MediaProgressNotifier.notifyCompressing(percent),
            );
          }

          // CRITICAL: Update file reference if compression was successful
          if (compressedFile != null &&
              compressedFile.path != fileToProcess.path) {
            AppLogger.info('Using compressed file at ${compressedFile.path}');
            fileToProcess = compressedFile;
          }
        }

        // --- Final Size Validation (STRICT ENFORCEMENT) ---
        final finalBytes = await fileToProcess.length();
        AppLogger.info('Final file size after compression: $finalBytes bytes');

        if (finalBytes > maxSize) {
          AppLogger.error(
            'Media file too large after compression: $finalBytes bytes (max: $maxSize)',
          );

          final String mbSize = (finalBytes / (1024 * 1024)).toStringAsFixed(1);
          final String maxMbSize = (maxSize / (1024 * 1024)).toStringAsFixed(0);

          final String errorMessage = mediaType == 'video'
              ? 'Video must be less than ${maxMbSize}MB. Your file is ${mbSize}MB.'
              : 'Image must be less than ${maxMbSize}MB. Your file is ${mbSize}MB.';

          MediaProgressNotifier.notifyError(errorMessage);
          throw ServerException(errorMessage);
        }

        // --- Get Dimensions (MANDATORY) ---
        final dimensions = await getMediaDimensions(fileToProcess, mediaType);
        if (dimensions == null ||
            dimensions.width <= 0 ||
            dimensions.height <= 0) {
          // CRITICAL: Media dimensions are required for proper UI rendering
          AppLogger.error('Failed to get media dimensions for post creation');
          MediaProgressNotifier.notifyError('Failed to read media dimensions');
          throw ServerException(
            'Could not read media dimensions. The file may be corrupted or unsupported.',
          );
        }

        mediaWidth = dimensions.width;
        mediaHeight = dimensions.height;
        AppLogger.info('Media dimensions: ${mediaWidth}x${mediaHeight}');
      }

      // --- 2. Upload Media ---
      String? mediaUrl;
      String? thumbnailUrl;

      if (fileToProcess != null && mediaType != null) {
        AppLogger.info('Uploading media...');
        MediaProgressNotifier.notifyUploading(0.0);

        // This function is not defined in the prompt, assuming it exists
        final urls = await _uploadMediaAndGetUrls(
          userId: userId,
          mediaFile: fileToProcess,
          mediaType: mediaType,
          fileExt: mediaFileExt ?? 'file', // Use original extension
        );
        mediaUrl = urls['mediaUrl'];
        thumbnailUrl = urls['thumbnailUrl'];
      }

      // --- 3. Create Post Record in Database ---
      final postData = {
        'user_id': userId,
        'content': content,
        'media_type': mediaType ?? 'none',
        'media_width': mediaWidth,
        'media_height': mediaHeight,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
      };

      await client.from('posts').insert(postData);

      AppLogger.info('Post created successfully in database!');
      MediaProgressNotifier.notifyDone();

      // --- 4. Cleanup ---
      if (fileToProcess != null && fileToProcess.path != mediaFile?.path) {
        try {
          await fileToProcess.delete();
        } catch (_) {}
      }
    } catch (e, st) {
      AppLogger.error('Post creation failed: $e', error: e, stackTrace: st);

      // Re-throw with more specific error messages when possible
      if (e is ServerException) {
        MediaProgressNotifier.notifyError(e.message); // Show specific error
        rethrow; // Preserve original server exception
      } else {
        MediaProgressNotifier.notifyError('Post creation failed');
        throw ServerException('Post creation failed: ${e.toString()}');
      }
    }
  }

  /// [Private Helper] Uploads media and returns the public URLs.
  Future<Map<String, String?>> _uploadMediaAndGetUrls({
    required String userId,
    required File mediaFile,
    required String mediaType,
    required String fileExt,
  }) async {
    // Generate unique file path *once*
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
      return {'mediaUrl': mediaUrl, 'thumbnailUrl': thumbnailUrl};
    } catch (e) {
      AppLogger.error('Media processing failed during upload phase: $e');
      throw ServerException('Media upload failed: $e');
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
        'Uploading file to path: $uploadPath (size=$fileSize bytes)',
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
        'get_user_posts_with_status',
        params: {
          'p_profile_user_id': profileUserId, // ← CHANGED from p_post_user_id
          'p_current_user_id': currentUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );

      final rows = _normalizeRpcList(response);
      if (rows.isEmpty) return [];

      // Debug logging to verify dimensions
      if (rows.isNotEmpty) {
        final firstPost = rows.first as Map<String, dynamic>;
        AppLogger.info(
          'UserPosts RPC - First post dimensions: '
          'media_width=${firstPost['media_width']}, '
          'media_height=${firstPost['media_height']}',
        );
      }

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

  // ==================== Share Count ====================
  Future<void> sharePost({required String postId}) async {
    try {
      AppLogger.info('Attempting to share post: $postId');
      final shareUrl = 'Check this post: https://myapp.com/post/$postId';
      final result = await SharePlus.instance.share(
        ShareParams(text: shareUrl),
      );
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
              final data = {
                'id': id,
                'likes_count': newRec['likes_count'],
                'comments_count': newRec['comments_count'],
                'favorites_count': newRec['favorites_count'],
                'shares_count': newRec['shares_count'],
                'media_url': newRec['media_url'],
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
