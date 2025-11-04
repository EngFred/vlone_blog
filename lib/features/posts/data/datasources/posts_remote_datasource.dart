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

  Future<PostModel> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    try {
      AppLogger.info('Attempting to create post for user: $userId');
      String? mediaUrl;
      String? thumbnailUrl;
      // 🌟 NEW DIMENSION VARIABLES
      int? mediaWidth;
      int? mediaHeight;

      if (mediaFile != null) {
        // Use a local variable that may be replaced by a compressed file.
        File fileToUpload = mediaFile;

        try {
          // IMPORTANT: probe duration BEFORE copying or compressing. If duration exceeds allowed
          // threshold we want to fail fast and avoid expensive compression/IO.
          if (mediaType == 'video') {
            try {
              // NOTE: Assuming getVideoDuration is available via VideoCompressor or Helpers
              final duration = await getVideoDuration(fileToUpload);
              if (duration > Constants.maxVideoDurationSeconds) {
                AppLogger.warning(
                  'createPost: video duration $duration exceeds limit of ${Constants.maxVideoDurationSeconds}s',
                );
                throw const ServerException('Video exceeds allowed duration');
              }
            } catch (e) {
              // If probing fails, we don't block compression — compressor will also attempt duration checks,
              // but we log the probe failure for debugging.
              AppLogger.warning(
                'createPost: getVideoDuration probe failed: $e',
              );
            }
          }

          // --- Compression logic for both video and image ---
          // Determine if it's worth attempting compression (based on size threshold).
          bool shouldAttemptCompression = false;
          try {
            final bytes = await fileToUpload.length();
            final threshold = mediaType == 'video'
                ? VideoCompressor.defaultMinSizeBytes
                : ImageCompressor.defaultMaxSizeBytes;
            shouldAttemptCompression = bytes > threshold;
          } catch (e) {
            AppLogger.warning('createPost: failed to stat file size: $e');
            // fall through — still attempt compression to be safe
            shouldAttemptCompression = true;
          }

          if (shouldAttemptCompression) {
            File? compressedFile;
            if (mediaType == 'video') {
              // Notify UI we're starting compression for video only
              MediaProgressNotifier.notifyCompressing(0.0);

              compressedFile = await VideoCompressor.compressIfNeeded(
                fileToUpload,
                onProgress: (percent) {
                  // Forward progress to the global notifier (0..100)
                  MediaProgressNotifier.notifyCompressing(percent);
                },
              );
            } else if (mediaType == 'image') {
              // For images, compress silently without progress notifications
              compressedFile = await ImageCompressor.compressIfNeeded(
                fileToUpload,
              );
            }

            if (compressedFile != null &&
                compressedFile.path != fileToUpload.path) {
              AppLogger.info(
                'createPost: using compressed ${mediaType} at ${compressedFile.path}',
              );
              fileToUpload = compressedFile;
            } else {
              AppLogger.info(
                'createPost: compression skipped or no size reduction; using original',
              );
            }
          } else {
            AppLogger.info(
              'createPost: file below compression threshold; skipping compressor',
            );
          }
          // --- END compression wiring ---
        } catch (e) {
          AppLogger.warning(
            'createPost: compression step encountered error, proceeding with original file: $e',
          );
          // Surface to UI but continue
          try {
            MediaProgressNotifier.notifyError(
              'Compression step failed; uploading original',
            );
          } catch (_) {}
        }

        if (mediaType == 'image' || mediaType == 'video') {
          final dimensions = await getMediaDimensions(fileToUpload, mediaType!);
          mediaWidth = dimensions?.width;
          mediaHeight = dimensions?.height;
        }

        if (mediaType == 'video') {
          // Redundant safety check: confirm duration after any compression/trim step.
          try {
            final duration = await getVideoDuration(fileToUpload);
            if (duration > Constants.maxVideoDurationSeconds) {
              AppLogger.warning(
                'Video duration exceeds limit after compression: $duration seconds',
              );
              throw const ServerException('Video exceeds allowed duration');
            }
          } catch (e) {
            // If this probe fails, we accept the risk (we've already attempted compression).
            AppLogger.warning(
              'createPost: duration probe failed after compression: $e',
            );
          }
        }

        // --- notify uploading stage (UI will show "Uploading video..." and ignore percent) ---
        try {
          MediaProgressNotifier.notifyUploading(0.0);
        } catch (_) {}

        mediaUrl = await _uploadFileToStorage(
          file: fileToUpload,
          userId: userId,
          folder: 'posts/media',
        );

        // After upload succeeds, we can mark done for media stage (finalization happens later)
        try {
          MediaProgressNotifier.notifyDone();
        } catch (_) {}

        if (mediaType == 'video') {
          // This call now runs on the main thread, as required by the plugin
          final thumbPath = await _generateThumbnailFile(fileToUpload);

          if (thumbPath != null) {
            final thumbFile = File(thumbPath);
            final thumbUrl = await _uploadFileToStorage(
              file: thumbFile,
              userId: userId,
              folder: 'posts/thumbnails',
            );
            thumbnailUrl = thumbUrl;

            try {
              if (await thumbFile.exists()) {
                // Clean up local temp thumbnail file
                await thumbFile.delete();
              }
            } catch (_) {}
          }
        }
      }

      final postData = {
        'user_id': userId,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType ?? 'none',
        'thumbnail_url': thumbnailUrl,
        'media_width': mediaWidth,
        'media_height': mediaHeight,
      };

      // Standard select works here as it's a single insert/fetch
      final response = await client
          .from('posts')
          .insert(postData)
          .select('*, profiles ( username, profile_image_url )')
          .single();

      AppLogger.info('Post created successfully with ID: ${response['id']}');

      // Inject default status fields since this is a new post without user context check
      final postMap = response;
      postMap['is_liked'] = false;
      postMap['is_favorited'] = false;

      // Final overall done notification (UI will pop on PostCreated listener)
      try {
        MediaProgressNotifier.notifyDone();
      } catch (_) {}

      return PostModel.fromMap(postMap);
    } catch (e, st) {
      AppLogger.error('Error creating post: $e', error: e, stackTrace: st);
      try {
        MediaProgressNotifier.notifyError(e.toString());
      } catch (_) {}
      throw ServerException(e.toString());
    }
  }

  Future<String> _uploadFileToStorage({
    required File file,
    required String userId,
    required String folder,
  }) async {
    final fileExt = file.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';
    final uploadPath = '$folder/$userId/$fileName';

    try {
      final fileSize = await file.length();
      AppLogger.info(
        'Uploading file to path: $uploadPath (size=${fileSize} bytes)',
      );
      // Supabase .upload expects a File for mobile; keep your prior call
      await client.storage.from('posts').upload(uploadPath, file);
      final url = client.storage.from('posts').getPublicUrl(uploadPath);
      AppLogger.info('File uploaded successfully, url: $url');
      return url;
    } catch (e) {
      AppLogger.error(
        'Upload failed, scheduling background upload: $e',
        error: e,
      );

      // Save a local copy so the background worker can retry from disk
      try {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';
        await file.copy(tempPath);

        // Schedule background upload via Workmanager
        Workmanager().registerOneOffTask(
          'upload_post_media_$fileName',
          'upload_media',
          inputData: {
            'bucket': 'posts',
            'uploadPath': uploadPath,
            'filePath': tempPath,
          },
        );
      } catch (copyError) {
        AppLogger.warning(
          'Failed to create local copy for background upload: $copyError',
        );
      }

      throw ServerException('Upload started in background: $e');
    }
  }

  //This method now calls the plugin directly
  Future<String?> _generateThumbnailFile(File videoFile) async {
    try {
      // 1. Get temp directory path
      final tempDir = await getTemporaryDirectory();

      // 2. Run the task directly.
      // The plugin itself is async and manages platform channels.
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath:
            tempDir.path, // The plugin will create a file IN this dir
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxHeight: 720,
      );

      if (thumbPath == null) {
        throw Exception('Thumbnail generation returned null');
      }

      AppLogger.info('Thumbnail generated at: $thumbPath');
      return thumbPath;
    } catch (e, st) {
      // This will now log the REAL error if the plugin fails
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

  /// Fetches the main feed using the `get_feed_with_user_status` RPC for efficiency.
  Future<List<PostModel>> getFeed({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      AppLogger.info(
        'Fetching feed via RPC for user: $currentUserId with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
      );

      // Call the consolidated Postgres function with pagination params
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

      AppLogger.info('Feed fetched with ${rows.length} posts via RPC');

      // Note: If 'rows' contained 10,000+ items, this 'map'
      // could also be a candidate for 'compute', but for a feed,
      // this is perfectly fine.
      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching feed via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Fetches Reels (video posts) using the optimized `get_posts_with_user_status` RPC.
  Future<List<PostModel>> getReels({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      AppLogger.info(
        'Fetching reels (video posts) via RPC with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
      );

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

      AppLogger.info('Reels fetched with ${rows.length} posts via RPC');

      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching reels via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Fetches posts for a specific user profile using the optimized `get_posts_with_user_status` RPC.
  Future<List<PostModel>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      AppLogger.info(
        'Fetching user posts for $profileUserId via RPC with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
      );

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

      AppLogger.info('User posts fetched with ${rows.length} posts via RPC');

      return rows
          .map((map) => PostModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching user posts via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Fetches a single post using the **new, efficient two-parameter** `get_post_with_profile` RPC.
  Future<PostModel> getPost({
    required String postId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info(
        'Fetching post: $postId using updated get_post_with_profile RPC',
      );

      final response = await _callRpcWithRetry(
        'get_post_with_profile',
        params: {'p_post_id': postId, 'p_current_user_id': currentUserId},
      );

      final rows = _normalizeRpcList(response);
      if (rows.isNotEmpty) {
        AppLogger.info('Post fetched successfully: ${rows.first['id']}');
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

  // NOTE: getFavorites method has been removed and moved to FavoritesRemoteDataSource.

  // ==================== RPC for Atomic Share Count ====================

  /// Shares a post and uses the `increment_post_shares` RPC to atomically update the share count.
  Future<void> sharePost({required String postId}) async {
    try {
      AppLogger.info('Attempting to share post: $postId');

      final shareUrl = 'Check this post: https://myapp.com/post/$postId';
      await Share.share(shareUrl);

      // RPC call is atomic and safe
      await _callRpcWithRetry(
        'increment_post_shares',
        params: {'post_id_param': postId},
      );

      AppLogger.info('Post shared and count updated successfully via RPC');
    } catch (e) {
      AppLogger.error('Error sharing post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      AppLogger.info('Attempting to delete post: $postId');

      final response = await client
          .from('posts')
          .delete()
          .eq('id', postId)
          .select();

      if (response.isEmpty) {
        AppLogger.error('No rows deleted for post: $postId');
        throw const ServerException('Post not found or unauthorized');
      }

      AppLogger.info('Post deleted successfully: $postId');
    } catch (e) {
      AppLogger.error('Error deleting post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  // ==================== Realtime streams ====================

  /// Stream for new posts being created.
  /// and attempts to fetch multiple posts in a single batched RPC call
  /// (`get_posts_batch`). If the batch RPC is not available the code falls
  /// back to fetching each post individually.
  Stream<PostModel> streamNewPosts() {
    AppLogger.info('Setting up real-time stream for new posts (coalesced)');

    // Reuse existing controller if present
    if (_newPostsController != null && !_newPostsController!.isClosed) {
      AppLogger.info('Returning existing new posts stream');
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

      // Split into chunks to respect _maxBatchSize
      for (int i = 0; i < ids.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < ids.length)
            ? i + _maxBatchSize
            : ids.length;
        final chunk = ids.sublist(i, end);

        try {
          final batchResponse = await _callRpcWithRetry(
            'get_posts_batch',
            params: {'p_post_ids': chunk},
          );
          final rows = _normalizeRpcList(batchResponse);
          for (final r in rows) {
            try {
              final map = r as Map<String, dynamic>;
              map['is_liked'] = map['is_liked'] ?? false;
              map['is_favorited'] = map['is_favorited'] ?? false;
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
            'Batch RPC failed, falling back to per-id fetch for chunk: $e',
          );
          for (final id in chunk) {
            try {
              final resp = await _callRpcWithRetry(
                'get_post_with_profile',
                params: {'post_id': id},
              );
              final rows = _normalizeRpcList(resp);
              if (rows.isNotEmpty) {
                final map = rows.first as Map<String, dynamic>;
                map['is_liked'] = map['is_liked'] ?? false;
                map['is_favorited'] = map['is_favorited'] ?? false;
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

              // If we've hit max batch size, flush immediately (avoid waiting)
              if (idBuffer.length >= _maxBatchSize) {
                if (flushTimer != null) {
                  flushTimer!.cancel();
                  flushTimer = null;
                }
                // Fire-and-forget flush
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

    // Unsubscribe when no listeners remain
    _newPostsController!.onCancel = () async {
      try {
        // Ensure any pending ids are flushed before unsubscribing
        if (flushTimer != null) {
          try {
            flushTimer!.cancel();
          } catch (_) {}
          await flushIds();
        }

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
      AppLogger.info('Returning existing posts updates stream');
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
              if (!(_postsController?.isClosed ?? true)) {
                _postsController!.addError(ServerException(e.toString()));
              }
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
      AppLogger.info('Returning existing post deletions stream');
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
              if (!(_postDeletionsController?.isClosed ?? true)) {
                _postDeletionsController!.addError(
                  ServerException(e.toString()),
                );
              }
            }
          },
        )
        .subscribe();

    _postDeletionsController!.onCancel = () async {
      try {
        if (!(_postDeletionsController?.hasListener ?? false)) {
          await _postDeletionsChannel?.unsubscribe();
          _postDeletionsChannel = null;
          if (!(_postDeletionsController?.isClosed ?? true))
            await _postDeletionsController?.close();
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
