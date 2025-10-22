import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class GetFollowingUseCase
    implements UseCase<List<UserListEntity>, GetFollowingParams> {
  final FollowersRepository repository;

  GetFollowingUseCase(this.repository);

  @override
  Future<Either<Failure, List<UserListEntity>>> call(
    GetFollowingParams params,
  ) {
    return repository.getFollowing(
      userId: params.userId,
      currentUserId: params.currentUserId,
    );
  }
}

class GetFollowingParams {
  final String userId;
  final String? currentUserId;

  GetFollowingParams({required this.userId, this.currentUserId});
}
