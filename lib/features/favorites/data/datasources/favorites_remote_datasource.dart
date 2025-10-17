import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
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
    try {
      if (isFavorited) {
        await client.from('favorites').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
        return FavoriteModel(
          id: '',
          postId: postId,
          userId: userId,
        ); // Dummy for toggle
      } else {
        final response = await client
            .from('favorites')
            .insert({'post_id': postId, 'user_id': userId})
            .select()
            .single();

        return FavoriteModel.fromMap(response);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getFavorites({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('favorites')
          .select('posts(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      return response.map((map) => PostModel.fromMap(map['posts'])).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
