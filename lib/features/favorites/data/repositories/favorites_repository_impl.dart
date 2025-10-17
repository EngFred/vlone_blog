import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/favorites/data/datasources/favorites_remote_datasource.dart';
import 'package:vlone_blog_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:vlone_blog_app/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesRemoteDataSource remoteDataSource;

  FavoritesRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, FavoriteEntity>> addFavorite({
    required String postId,
    required String userId,
    required bool isFavorited,
  }) async {
    try {
      final favoriteModel = await remoteDataSource.addFavorite(
        postId: postId,
        userId: userId,
        isFavorited: isFavorited,
      );
      return Right(favoriteModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final postModels = await remoteDataSource.getFavorites(
        userId: userId,
        page: page,
        limit: limit,
      );
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
