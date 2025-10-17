import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

class CommentsRepositoryImpl implements CommentsRepository {
  final CommentsRemoteDataSource remoteDataSource;

  CommentsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, CommentEntity>> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      final commentModel = await remoteDataSource.addComment(
        postId: postId,
        userId: userId,
        text: text,
        parentCommentId: parentCommentId,
      );
      return Right(commentModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId,
  ) async {
    try {
      final commentModels = await remoteDataSource.getComments(postId);
      return Right(commentModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<CommentEntity>> getCommentsStream(String postId) {
    return remoteDataSource
        .getCommentsStream(postId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
