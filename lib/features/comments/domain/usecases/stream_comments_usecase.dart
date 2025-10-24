import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

/// Use case for streaming comment events
class StreamCommentsUseCase
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  final CommentsRepository repository;

  StreamCommentsUseCase(this.repository);

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params) {
    return repository.streamCommentEvents();
  }
}
