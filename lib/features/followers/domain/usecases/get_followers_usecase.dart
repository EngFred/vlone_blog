import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';

class GetFollowersUseCase
    implements UseCase<List<ProfileEntity>, GetFollowersParams> {
  final FollowersRepository repository;

  GetFollowersUseCase(this.repository);

  @override
  Future<Either<Failure, List<ProfileEntity>>> call(GetFollowersParams params) {
    return repository.getFollowers(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetFollowersParams {
  final String userId;
  final int page;
  final int limit;

  GetFollowersParams({required this.userId, this.page = 1, this.limit = 20});
}
