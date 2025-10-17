import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';

class GetFollowingUseCase
    implements UseCase<List<ProfileEntity>, GetFollowingParams> {
  final FollowersRepository repository;

  GetFollowingUseCase(this.repository);

  @override
  Future<Either<Failure, List<ProfileEntity>>> call(GetFollowingParams params) {
    return repository.getFollowing(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetFollowingParams {
  final String userId;
  final int page;
  final int limit;

  GetFollowingParams({required this.userId, this.page = 1, this.limit = 20});
}
