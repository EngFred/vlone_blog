import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/data/models/favorite_model.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';

class FavoritesRemoteDataSource {
  final SupabaseClient client;

  FavoritesRemoteDataSource(this.client);

  Future<FavoriteModel> addFavorite({
    required String postId,
    required String userId,
    required bool isFavorited,
  }) async {
    AppLogger.info(
      'Attempting to ${isFavorited ? 'remove' : 'add'} favorite for post: $postId by user: $userId',
    );
    try {
      if (isFavorited) {
        AppLogger.info('Removing favorite for post: $postId by user: $userId');
        await client.from('favorites').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
        AppLogger.info('Favorite removed successfully');
        return FavoriteModel(id: '', postId: postId, userId: userId);
      } else {
        AppLogger.info('Adding favorite for post: $postId by user: $userId');
        final response = await client
            .from('favorites')
            .insert({'post_id': postId, 'user_id': userId})
            .select()
            .single();
        AppLogger.info('Favorite added successfully');
        return FavoriteModel.fromMap(response);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to ${isFavorited ? 'remove' : 'add'} favorite for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getFavorites({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    AppLogger.info(
      'Fetching favorites for user: $userId, page: $page, limit: $limit',
    );
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;
      final response = await client
          .from('favorites')
          .select('posts(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      final favorites = response
          .map((map) => PostModel.fromMap(map['posts']))
          .toList();
      AppLogger.info('Fetched ${favorites.length} favorites for user: $userId');
      return favorites;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch favorites for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }
}
