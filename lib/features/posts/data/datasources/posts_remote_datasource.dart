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
  RealtimeChannel? _likesChannel;
  RealtimeChannel? _commentsChannel;
  RealtimeChannel? _favoritesChannel;
  RealtimeChannel? _postDeletionsChannel;

  // Stream controllers for manual stream management
  StreamController<Map<String, dynamic>>? _postsController;
  StreamController<Map<String, dynamic>>? _likesController;
  StreamController<Map<String, dynamic>>? _commentsController;
  StreamController<Map<String, dynamic>>? _favoritesController;
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
      return PostModel.fromMap(response);
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
      return (response as List).map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching feed via RPC: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  // Sticking to original select/join method for Reels and UserPosts
  Future<List<PostModel>> getReels({required String currentUserId}) async {
    try {
      AppLogger.info('Fetching reels (video posts)');

      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .eq('media_type', 'video')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      final likedResponse = await client
          .from('likes')
          .select('post_id')
          .eq('user_id', currentUserId);
      final likedIds = likedResponse.map((e) => e['post_id'] as String).toSet();

      final favoritedResponse = await client
          .from('favorites')
          .select('post_id')
          .eq('user_id', currentUserId);
      final favoritedIds = favoritedResponse
          .map((e) => e['post_id'] as String)
          .toSet();

      for (var map in response) {
        map['is_liked'] = likedIds.contains(map['id']);
        map['is_favorited'] = favoritedIds.contains(map['id']);
      }

      AppLogger.info('Reels fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching reels: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('Fetching user posts for $profileUserId');
      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .eq('user_id', profileUserId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      final likedResponse = await client
          .from('likes')
          .select('post_id')
          .eq('user_id', currentUserId);
      final likedIds = likedResponse.map((e) => e['post_id'] as String).toSet();

      final favoritedResponse = await client
          .from('favorites')
          .select('post_id')
          .eq('user_id', currentUserId);
      final favoritedIds = favoritedResponse
          .map((e) => e['post_id'] as String)
          .toSet();

      for (var map in response) {
        map['is_liked'] = likedIds.contains(map['id']);
        map['is_favorited'] = favoritedIds.contains(map['id']);
      }

      AppLogger.info('User posts fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching user posts: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<PostModel> getPost({
    required String postId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('Fetching post: $postId');
      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .eq('id', postId)
          .single();

      final likeCheck = await client
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .maybeSingle();
      final isLiked = likeCheck != null;

      final favCheck = await client
          .from('favorites')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .maybeSingle();
      final isFavorited = favCheck != null;

      response['is_liked'] = isLiked;
      response['is_favorited'] = isFavorited;

      AppLogger.info('Post fetched: ${response['id']}');
      return PostModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error fetching post $postId: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getFavorites({required String userId}) async {
    try {
      AppLogger.info('Fetching favorites for user: $userId');
      final response = await client
          .from('favorites')
          .select('post_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final postIds = response.map((fav) => fav['post_id'] as String).toList();

      if (postIds.isEmpty) {
        AppLogger.info('No favorites found for user: $userId');
        return [];
      }

      final postsResponse = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .inFilter('id', postIds)
          .order('created_at', ascending: false);

      final likedResponse = await client
          .from('likes')
          .select('post_id')
          .eq('user_id', userId);
      final likedIds = likedResponse.map((e) => e['post_id'] as String).toSet();

      for (var map in postsResponse) {
        map['is_favorited'] = true;
        map['is_liked'] = likedIds.contains(map['id']);
      }

      AppLogger.info('Favorites fetched with ${postsResponse.length} posts');
      return postsResponse.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching favorites: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      AppLogger.info(
        'Attempting to ${isLiked ? 'like' : 'unlike'} post: $postId by user: $userId',
      );

      if (isLiked) {
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await client.from('likes').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
      }

      AppLogger.info('Like/unlike successful for post: $postId');
    } catch (e) {
      AppLogger.error('Error liking post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> favoritePost({
    required String postId,
    required String userId,
    required bool isFavorited,
  }) async {
    try {
      AppLogger.info(
        'Attempting to ${isFavorited ? 'favorite' : 'unfavorite'} post: $postId by user: $userId',
      );

      if (isFavorited) {
        await client.from('favorites').insert({
          'post_id': postId,
          'user_id': userId,
        });
        AppLogger.info('Post favorited successfully: $postId');
      } else {
        await client.from('favorites').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
        AppLogger.info('Post unfavorited successfully: $postId');
      }
    } catch (e) {
      AppLogger.error('Error favoriting post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

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

  // ==================== RPC for Real-Time Data Enrichment ====================

  /// Stream for new posts being created. Uses the `get_post_with_profile` RPC function.
  Stream<PostModel> streamNewPosts() {
    AppLogger.info('Setting up real-time stream for new posts (using RPC)');

    return client
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          if (data.isEmpty) return null;

          final latestPost = data.first;
          final postId = latestPost['id'] as String;

          try {
            // Use the Postgres function to fetch the complete data
            final response = await client.rpc(
              'get_post_with_profile',
              params: {'post_id': postId},
            );

            if (response is List && response.isNotEmpty) {
              // Model handles the flat RPC structure directly now
              return PostModel.fromMap(response.first);
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

    _postsChannel?.unsubscribe();
    _postsController?.close();

    _postsController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'posts_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _postsChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            AppLogger.info('Post update received: ${payload.newRecord['id']}');

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
          },
        )
        .subscribe();

    return _postsController!.stream;
  }

  /// Stream for likes on specific posts
  Stream<Map<String, dynamic>> streamLikes() {
    AppLogger.info('Setting up real-time stream for likes');

    _likesChannel?.unsubscribe();
    _likesController?.close();

    _likesController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'likes_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _likesChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            AppLogger.info('Like event received: ${payload.eventType}');

            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;

            final data = {
              'event': payload.eventType.name,
              'post_id': record['post_id'],
              'user_id': record['user_id'],
            };

            if (!(_likesController?.isClosed ?? true)) {
              _likesController!.add(data);
            }
          },
        )
        .subscribe();

    return _likesController!.stream.handleError((error) {
      AppLogger.error('Error in likes stream: $error', error: error);
    });
  }

  /// Stream for comments on posts
  Stream<Map<String, dynamic>> streamComments() {
    AppLogger.info('Setting up real-time stream for comments');

    _commentsChannel?.unsubscribe();
    _commentsController?.close();

    _commentsController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'comments_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _commentsChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            AppLogger.info(
              'Comment event received on post: ${payload.newRecord['post_id']}',
            );

            final data = {
              'event': 'INSERT',
              'post_id': payload.newRecord['post_id'],
              'user_id': payload.newRecord['user_id'],
              'comment_id': payload.newRecord['id'],
            };

            if (!(_commentsController?.isClosed ?? true)) {
              _commentsController!.add(data);
            }
          },
        )
        .subscribe();

    return _commentsController!.stream.handleError((error) {
      AppLogger.error('Error in comments stream: $error', error: error);
    });
  }

  /// Stream for favorites
  Stream<Map<String, dynamic>> streamFavorites() {
    AppLogger.info('Setting up real-time stream for favorites');

    _favoritesChannel?.unsubscribe();
    _favoritesController?.close();

    _favoritesController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'favorites_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _favoritesChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'favorites',
          callback: (payload) {
            AppLogger.info('Favorite event received: ${payload.eventType}');

            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;

            final data = {
              'event': payload.eventType.name,
              'post_id': record['post_id'],
              'user_id': record['user_id'],
            };

            if (!(_favoritesController?.isClosed ?? true)) {
              _favoritesController!.add(data);
            }
          },
        )
        .subscribe();

    return _favoritesController!.stream.handleError((error) {
      AppLogger.error('Error in favorites stream: $error', error: error);
    });
  }

  /// Stream for post deletions
  Stream<String> streamPostDeletions() {
    AppLogger.info('Setting up real-time stream for post deletions');

    _postDeletionsChannel?.unsubscribe();
    _postDeletionsController?.close();

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
            final deletedPostId = payload.oldRecord['id'] as String;
            AppLogger.info('Post deletion detected: $deletedPostId');

            if (!(_postDeletionsController?.isClosed ?? true)) {
              _postDeletionsController!.add(deletedPostId);
            }
          },
        )
        .subscribe();

    return _postDeletionsController!.stream.handleError((error) {
      AppLogger.error('Error in post deletions stream: $error', error: error);
    });
  }

  /// Cleanup method to unsubscribe from all channels
  void dispose() {
    AppLogger.info('Disposing PostsRemoteDataSource - cleaning up channels');
    _postsChannel?.unsubscribe();
    _likesChannel?.unsubscribe();
    _commentsChannel?.unsubscribe();
    _favoritesChannel?.unsubscribe();
    _postDeletionsChannel?.unsubscribe();

    _postsController?.close();
    _likesController?.close();
    _commentsController?.close();
    _favoritesController?.close();
    _postDeletionsController?.close();
  }
}
