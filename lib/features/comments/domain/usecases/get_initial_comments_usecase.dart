import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

class GetInitialCommentsUseCase
    implements UseCase<List<CommentEntity>, String> {
  final CommentsRepository repository;

  GetInitialCommentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<CommentEntity>>> call(String postId) {
    return repository.getInitialComments(postId);
  }
}
