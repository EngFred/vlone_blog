import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/data/datasources/favorites_data_source.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart'; // Needed for getFavorites return type

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesRemoteDataSource remoteDataSource;

  FavoritesRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, Unit>> favoritePost({
    required String postId,
    required String userId,
    required bool isFavorited,
  }) async {
    try {
      await remoteDataSource.favoritePost(
        postId: postId,
        userId: userId,
        isFavorited: isFavorited,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in favoritePost repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
  }) async {
    try {
      // remoteDataSource.getFavorites returns PostModel list
      final postModels = await remoteDataSource.getFavorites(userId: userId);
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in getFavorites repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamFavorites() {
    try {
      AppLogger.info('Repository: Setting up favorites stream');

      // streamFavoriteEvents is the method name in FavoritesRemoteDataSource
      return remoteDataSource
          .streamFavoriteEvents()
          .map(
            (favoriteEvent) =>
                Right<Failure, Map<String, dynamic>>(favoriteEvent),
          )
          .handleError((error) {
            AppLogger.error(
              'Error in streamFavorites repo: $error',
              error: error,
            );
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      AppLogger.error('Exception setting up streamFavorites: $e', error: e);
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
