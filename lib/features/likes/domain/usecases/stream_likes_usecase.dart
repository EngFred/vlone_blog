import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/repository/likes_repository.dart';

/// Use case for streaming like events
class StreamLikesUseCase
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  final LikesRepository repository;

  StreamLikesUseCase(this.repository);

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params) {
    return repository.streamLikes();
  }
}
