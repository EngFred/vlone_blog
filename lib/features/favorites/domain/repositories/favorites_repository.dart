import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

abstract class FavoritesRepository {
  Future<Either<Failure, FavoriteEntity>> addFavorite({
    required String postId,
    required String userId,
    required bool isFavorited,
  });
  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
    int page = 1,
    int limit = 20,
  });
}
