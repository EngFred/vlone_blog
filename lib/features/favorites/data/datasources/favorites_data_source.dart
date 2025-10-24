import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';

class FavoritesRemoteDataSource {
  final SupabaseClient client;

  RealtimeChannel? _favoritesChannel;
  StreamController<Map<String, dynamic>>? _favoritesController;

  FavoritesRemoteDataSource(this.client);

  /// Fetches a list of posts that the specified user has favorited.
  Future<List<PostModel>> getFavorites({required String userId}) async {
    try {
      AppLogger.info('Fetching favorites for user: $userId');

      // 1. Get all favorite records for the user
      final favoritesResponse = await client
          .from('favorites')
          .select('post_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final postIds = favoritesResponse
          .map((fav) => fav['post_id'] as String)
          .toList();

      if (postIds.isEmpty) {
        AppLogger.info('No favorites found for user: $userId');
        return [];
      }

      // 2. Fetch the actual posts and profile data
      final postsResponse = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .inFilter('id', postIds)
          .order('created_at', ascending: false);

      // 3. Determine which of these posts the user has LIKED (since the original data had this status)
      final likedResponse = await client
          .from('likes')
          .select('post_id')
          .eq('user_id', userId);
      final likedIds = likedResponse.map((e) => e['post_id'] as String).toSet();

      // 4. Transform and inject status fields
      for (var map in postsResponse) {
        // Since we filtered by favorites, all posts here are favorited
        map['is_favorited'] = true;
        // Check if the post is also liked
        map['is_liked'] = likedIds.contains(map['id']);
      }

      AppLogger.info('Favorites fetched with ${postsResponse.length} posts');
      return postsResponse.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching favorites: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  // ==================== Existing Methods ====================

  /// Handles favoriting or unfavoriting a post.
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

  /// Stream for all favorite/unfavorite events.
  /// Useful for updating UI counts on a feed.
  Stream<Map<String, dynamic>> streamFavoriteEvents() {
    AppLogger.info('Setting up real-time stream for favorites');

    if (_favoritesController != null && !_favoritesController!.isClosed) {
      AppLogger.info('Returning existing favorites stream');
      return _favoritesController!.stream.handleError((error) {
        AppLogger.error('Error in favorites stream: $error', error: error);
      });
    }

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
            try {
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
            } catch (e, st) {
              AppLogger.error(
                'Error handling favorite payload: $e',
                error: e,
                stackTrace: st,
              );
              if (!(_favoritesController?.isClosed ?? true)) {
                _favoritesController!.addError(ServerException(e.toString()));
              }
            }
          },
        )
        .subscribe();

    _favoritesController!.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_favoritesController?.hasListener ?? false)) {
        try {
          await _favoritesChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_favoritesController?.isClosed ?? true))
            await _favoritesController?.close();
        } catch (_) {}
        _favoritesChannel = null;
        _favoritesController = null;
        AppLogger.info('Favorites stream cancelled and cleaned up');
      }
    };

    return _favoritesController!.stream.handleError((error) {
      AppLogger.error('Error in favorites stream: $error', error: error);
    });
  }

  /// Cleanup method
  void dispose() {
    AppLogger.info('Disposing FavoritesRemoteDataSource');
    try {
      _favoritesChannel?.unsubscribe();
    } catch (_) {}
    try {
      _favoritesController?.close();
    } catch (_) {}
  }
}
