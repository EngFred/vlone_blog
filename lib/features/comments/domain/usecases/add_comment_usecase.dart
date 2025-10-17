import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

class AddCommentUseCase implements UseCase<CommentEntity, AddCommentParams> {
  final CommentsRepository repository;

  AddCommentUseCase(this.repository);

  @override
  Future<Either<Failure, CommentEntity>> call(AddCommentParams params) {
    return repository.addComment(
      postId: params.postId,
      userId: params.userId,
      text: params.text,
      parentCommentId: params.parentCommentId,
    );
  }
}

class AddCommentParams {
  final String postId;
  final String userId;
  final String text;
  final String? parentCommentId;

  AddCommentParams({
    required this.postId,
    required this.userId,
    required this.text,
    this.parentCommentId,
  });
}
