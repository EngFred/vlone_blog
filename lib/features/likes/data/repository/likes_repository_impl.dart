import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/likes/data/datasources/likes_remote_data_source.dart';
import 'package:vlone_blog_app/features/likes/domain/repository/likes_repository.dart';

class LikesRepositoryImpl implements LikesRepository {
  final LikesRemoteDataSource remoteDataSource;

  LikesRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, Unit>> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      await remoteDataSource.likePost(
        postId: postId,
        userId: userId,
        isLiked: isLiked,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in likePost repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamLikes() {
    try {
      AppLogger.info('Repository: Setting up likes stream');

      return remoteDataSource
          .streamLikeEvents()
          .map((likeEvent) => Right<Failure, Map<String, dynamic>>(likeEvent))
          .handleError((error) {
            AppLogger.error('Error in streamLikes repo: $error', error: error);
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      AppLogger.error('Exception setting up streamLikes: $e', error: e);
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
