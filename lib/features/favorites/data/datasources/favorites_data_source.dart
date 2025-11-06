import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';

class FavoritesRemoteDataSource {
  final SupabaseClient client;

  // Realtime channel and controller for global favorite events.
  RealtimeChannel? _favoritesChannel;
  StreamController<Map<String, dynamic>>? _favoritesController;

  FavoritesRemoteDataSource(this.client);

  /// Fetches a list of posts that the specified user has favorited.
  ///
  /// This is a multi-step query that first retrieves the favorited Post IDs
  /// and then fetches the full post and profile data, manually injecting the
  /// favorited and liked status into the resulting [PostModel]s. Its not used in the app however, and it would be fine as a single server RPC instead.
  /// but since im not using it in the app, im ignoring it.
  Future<List<PostModel>> getFavorites({required String userId}) async {
    try {
      AppLogger.info('Fetching favorites for user: $userId');

      // 1. Getting all favorite records (Post IDs) for the user.
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

      // 2. Fetching the actual posts and profile data using the collected IDs.
      final postsResponse = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .inFilter('id', postIds)
          .order('created_at', ascending: false);

      // 3. Determining which of these posts the user has LIKED for status injection.
      final likedResponse = await client
          .from('likes')
          .select('post_id')
          .eq('user_id', userId);
      final likedIds = likedResponse.map((e) => e['post_id'] as String).toSet();

      // 4. Transforming the response and injecting calculated status fields.
      for (var map in postsResponse) {
        // All posts in this response are favorited by definition.
        map['is_favorited'] = true;

        // Checking if the post is also liked.
        map['is_liked'] = likedIds.contains(map['id']);
      }

      AppLogger.info('Favorites fetched with ${postsResponse.length} posts');
      return postsResponse.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching favorites: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Toggles the favorite status of a post.
  ///
  /// Inserts a record if `isFavorited` is true (favoriting) or deletes a record
  /// if `isFavorited` is false (unfavoriting).
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

  /// Provides a real-time stream for all favorite/unfavorite events across the application.
  ///
  /// This is highly useful for updating post favorite counts on a feed view without
  /// manually polling or refetching post data.
  Stream<Map<String, dynamic>> streamFavoriteEvents() {
    AppLogger.info('Setting up real-time stream for favorites');

    if (_favoritesController != null && !_favoritesController!.isClosed) {
      AppLogger.info('Returning existing favorites stream');
      return _favoritesController!.stream.handleError((error) {
        AppLogger.error('Error in favorites stream: $error', error: error);
      });
    }

    _favoritesController = StreamController<Map<String, dynamic>>.broadcast();

    // Using a unique channel name to prevent potential conflicts.
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

              // Determining which record to use based on the event type.
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

    // Cleanup logic: unsubscribe and close resources when all listeners are gone.
    _favoritesController!.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_favoritesController?.hasListener ?? false)) {
        try {
          await _favoritesChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_favoritesController?.isClosed ?? true)) {
            await _favoritesController?.close();
          }
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

  /// Cleans up the real-time channel and stream controller.
  ///
  /// This should be called when the data source is no longer needed (e.g., app shutdown).
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
