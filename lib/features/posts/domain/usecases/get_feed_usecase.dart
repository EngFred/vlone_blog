import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetFeedUseCase implements UseCase<List<PostEntity>, NoParams> {
  final PostsRepository repository;
  GetFeedUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(NoParams params) {
    return repository.getFeed();
  }
}
