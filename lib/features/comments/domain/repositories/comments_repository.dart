import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

abstract class CommentsRepository {
  Future<Either<Failure, CommentEntity>> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
  });

  Future<Either<Failure, List<CommentEntity>>> getInitialComments(
    String postId, {
    int pageSize = 20,
  });

  Future<Either<Failure, List<CommentEntity>>> loadMoreComments(
    String postId, {
    required DateTime lastCreatedAt,
    required String lastId,
    int pageSize = 20,
  });

  Stream<List<CommentEntity>> getCommentsStream(String postId);

  Stream<Either<Failure, Map<String, dynamic>>> streamCommentEvents();
}
