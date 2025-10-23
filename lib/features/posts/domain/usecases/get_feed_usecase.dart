import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetFeedParams {
  final String currentUserId;

  const GetFeedParams({required this.currentUserId});
}

class GetFeedUseCase implements UseCase<List<PostEntity>, GetFeedParams> {
  final PostsRepository repository;

  const GetFeedUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFeedParams params) {
    return repository.getFeed(currentUserId: params.currentUserId);
  }
}
