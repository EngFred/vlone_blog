import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/repositories/profile_repository.dart';

class GetUserPostsUseCase
    implements UseCase<List<PostEntity>, GetUserPostsParams> {
  final ProfileRepository repository;

  GetUserPostsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetUserPostsParams params) {
    return repository.getUserPosts(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetUserPostsParams {
  final String userId;
  final int page;
  final int limit;

  GetUserPostsParams({required this.userId, this.page = 1, this.limit = 20});
}
