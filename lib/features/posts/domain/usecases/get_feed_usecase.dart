import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetFeedUseCase implements UseCase<List<PostEntity>, GetFeedParams> {
  final PostsRepository repository;

  GetFeedUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFeedParams params) {
    return repository.getFeed(page: params.page, limit: params.limit);
  }
}

class GetFeedParams {
  final int page;
  final int limit;

  GetFeedParams({this.page = 1, this.limit = 20});
}
