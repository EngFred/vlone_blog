import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/favorites/data/datasources/favorites_data_source.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

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
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
  }) async {
    try {
      final postModels = await remoteDataSource.getFavorites(userId: userId);
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamFavorites() {
    try {
      return remoteDataSource
          .streamFavoriteEvents()
          .map(
            (favoriteEvent) =>
                Right<Failure, Map<String, dynamic>>(favoriteEvent),
          )
          .handleError((error) {
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
