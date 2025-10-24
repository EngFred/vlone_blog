import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';
import 'package:workmanager/workmanager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class PostsRemoteDataSource {
  final SupabaseClient client;

  // Store channel references for cleanup
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _postDeletionsChannel;

  // Stream controllers for manual stream management (lazily initialized)
  StreamController<Map<String, dynamic>>? _postsController;
  StreamController<String>? _postDeletionsController;

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

      if (mediaFile != null) {
        if (mediaType == 'video') {
          // Assuming getVideoDuration is available from helpers.dart
          final duration = await getVideoDuration(mediaFile);
          if (duration > Constants.maxVideoDurationSeconds) {
            AppLogger.warning(
              'Video duration exceeds limit: $duration seconds',
            );
            throw const ServerException('Video exceeds allowed duration');
          }
        }

        mediaUrl = await _uploadFileToStorage(
          file: mediaFile,
          userId: userId,
          folder: 'posts/media',
        );

        if (mediaType == 'video') {
          final thumbPath = await _generateThumbnailFile(mediaFile);
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
      return PostModel.fromMap(postMap);
    } catch (e) {
      AppLogger.error('Error creating post: $e', error: e);
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
      AppLogger.info('Uploading file to path: $uploadPath');
      await client.storage.from('posts').upload(uploadPath, file);
      final url = client.storage.from('posts').getPublicUrl(uploadPath);
      AppLogger.info('File uploaded successfully, url: $url');
      return url;
    } catch (e) {
      AppLogger.error(
        'Upload failed, scheduling background upload: $e',
        error: e,
      );

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await file.copy(tempPath);

      Workmanager().registerOneOffTask(
        'upload_post_media_$fileName',
        'upload_media',
        inputData: {
          'bucket': 'posts',
          'uploadPath': uploadPath,
          'filePath': tempPath,
        },
      );

      throw ServerException('Upload started in background: $e');
    }
  }

  Future<String?> _generateThumbnailFile(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxHeight: 720,
      );
      return thumbPath;
    } catch (e) {
      AppLogger.error('Thumbnail generation failed: $e', error: e);
      return null;
    }
  }

  // ==================== RPC for Feed Retrieval ====================

  /// Fetches the main feed using the `get_feed_with_user_status` RPC for efficiency.
  Future<List<PostModel>> getFeed({required String currentUserId}) async {
    try {
      AppLogger.info('Fetching feed via RPC for user: $currentUserId');

      // Call the consolidated Postgres function
      final response = await client.rpc(
        'get_feed_with_user_status',
        params: {'current_user_id': currentUserId},
      );

      if (response is List && response.isEmpty) {
        return [];
      }

      AppLogger.info(
        'Feed fetched with ${(response as List).length} posts via RPC',
      );

      // Model handles the flat RPC structure directly now
      return (response).map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching feed via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Fetches Reels (video posts) using the optimized `get_posts_with_user_status` RPC.
  Future<List<PostModel>> getReels({required String currentUserId}) async {
    try {
      AppLogger.info('Fetching reels (video posts) via RPC');

      // Call the consolidated Postgres function for reels (media_type = 'video')
      final response = await client.rpc(
        'get_posts_with_user_status',
        params: {'p_current_user_id': currentUserId, 'p_media_type': 'video'},
      );

      if (response is List && response.isEmpty) {
        return [];
      }

      AppLogger.info(
        'Reels fetched with ${(response as List).length} posts via RPC',
      );

      // Model handles the flat RPC structure directly now
      return (response).map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching reels via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Fetches posts for a specific user profile using the optimized `get_posts_with_user_status` RPC.
  Future<List<PostModel>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('Fetching user posts for $profileUserId via RPC');

      // Call the consolidated Postgres function filtering by user ID
      final response = await client.rpc(
        'get_posts_with_user_status',
        params: {
          'p_current_user_id': currentUserId,
          'p_post_user_id': profileUserId,
        },
      );

      if (response is List && response.isEmpty) {
        return [];
      }

      AppLogger.info(
        'User posts fetched with ${(response as List).length} posts via RPC',
      );

      return (response).map((map) => PostModel.fromMap(map)).toList();
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

      //Use the new 2-parameter overloaded function signature for efficiency.
      final response = await client.rpc(
        'get_post_with_profile',
        params: {
          // Parameters match the new function signature in SQL
          'p_post_id': postId,
          'p_current_user_id': currentUserId,
        },
      );

      // The RPC returns a list (even if it's just one item).
      if (response is List && response.isNotEmpty) {
        AppLogger.info('Post fetched successfully: ${response.first['id']}');
        return PostModel.fromMap(response.first as Map<String, dynamic>);
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
      await client.rpc(
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

  // ==================== REAL-TIME STREAMS ====================

  /// Stream for new posts being created. Uses the **original one-parameter** `get_post_with_profile` RPC.
  Stream<PostModel> streamNewPosts() {
    AppLogger.info(
      'Setting up real-time stream for new posts (using 1-param RPC)',
    );

    return client
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          if (data.isEmpty) return null;

          final latestPost = data.first;
          final postId = latestPost['id'] as String;

          try {
            //The stream uses the original 1-parameter function signature.
            final response = await client.rpc(
              'get_post_with_profile',
              params: {'post_id': postId},
            );

            if (response is List && response.isNotEmpty) {
              final postMap = response.first as Map<String, dynamic>;
              // Manually inject default status fields for the model to work
              postMap['is_liked'] = false;
              postMap['is_favorited'] = false;
              return PostModel.fromMap(postMap);
            }

            AppLogger.warning(
              'RPC get_post_with_profile returned no data for $postId',
            );
            return null;
          } catch (e) {
            AppLogger.error(
              'Error fetching complete post data via RPC: $e',
              error: e,
            );
            return null;
          }
        })
        .where((post) => post != null)
        .cast<PostModel>()
        .handleError((error) {
          AppLogger.error('Error in new posts stream: $error', error: error);
        });
  }

  /// Stream for post updates (likes_count, comments_count, etc.)
  Stream<Map<String, dynamic>> streamPostUpdates() {
    AppLogger.info('Setting up real-time stream for post updates');

    // If already created, return existing stream
    if (_postsController != null && !_postsController!.isClosed) {
      AppLogger.info('Returning existing posts updates stream');
      return _postsController!.stream;
    }

    // Create the controller before subscribing so callbacks can reference it safely
    _postsController = StreamController<Map<String, dynamic>>.broadcast();

    // Create channel and subscribe
    final channel = client.channel(
      'posts_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _postsChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              AppLogger.info(
                'Post update received: ${payload.newRecord['id']}',
              );

              final data = {
                'id': payload.newRecord['id'],
                'likes_count': payload.newRecord['likes_count'],
                'comments_count': payload.newRecord['comments_count'],
                'favorites_count': payload.newRecord['favorites_count'],
                'shares_count': payload.newRecord['shares_count'],
              };

              if (!(_postsController?.isClosed ?? true)) {
                _postsController!.add(data);
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

    // Cleanup when last listener cancels: cancel channel & close controller
    _postsController!.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_postsController?.hasListener ?? false)) {
        try {
          await _postsChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_postsController?.isClosed ?? true)) {
            await _postsController?.close();
          }
        } catch (_) {}
        _postsChannel = null;
        _postsController = null;
        AppLogger.info('Posts updates stream cancelled and cleaned up');
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
      return _postDeletionsController!.stream.handleError((error) {
        AppLogger.error('Error in post deletions stream: $error', error: error);
      });
    }

    _postDeletionsController = StreamController<String>.broadcast();

    final channel = client.channel(
      'post_deletions_${DateTime.now().millisecondsSinceEpoch}',
    );

    _postDeletionsChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              final deletedPostId = payload.oldRecord['id'] as String;
              AppLogger.info('Post deletion detected: $deletedPostId');

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
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_postDeletionsController?.hasListener ?? false)) {
        try {
          await _postDeletionsChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_postDeletionsController?.isClosed ?? true)) {
            await _postDeletionsController?.close();
          }
        } catch (_) {}
        _postDeletionsChannel = null;
        _postDeletionsController = null;
        AppLogger.info('Post deletions stream cancelled and cleaned up');
      }
    };

    return _postDeletionsController!.stream.handleError((error) {
      AppLogger.error('Error in post deletions stream: $error', error: error);
    });
  }

  /// Cleanup method to unsubscribe from all channels
  void dispose() {
    AppLogger.info('Disposing PostsRemoteDataSource - cleaning up channels');
    try {
      _postsChannel?.unsubscribe();
    } catch (_) {}
    try {
      _postDeletionsChannel?.unsubscribe();
    } catch (_) {}

    try {
      _postsController?.close();
    } catch (_) {}
    try {
      _postDeletionsController?.close();
    } catch (_) {}
  }
}
