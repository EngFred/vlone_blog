import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class StreamPostDeletionsUseCase implements StreamUseCase<String, NoParams> {
  final PostsRepository repository;

  StreamPostDeletionsUseCase(this.repository);

  @override
  Stream<Either<Failure, String>> call(NoParams params) {
    return repository.streamPostDeletions();
  }
}
