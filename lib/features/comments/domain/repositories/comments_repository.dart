import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

abstract class CommentsRepository {
  Future<Either<Failure, CommentEntity>> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
  });
  Future<Either<Failure, List<CommentEntity>>> getComments(String postId);
  Stream<List<CommentEntity>> getCommentsStream(String postId);
}
