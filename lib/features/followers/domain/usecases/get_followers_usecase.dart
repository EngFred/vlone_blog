import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class GetFollowersUseCase
    implements UseCase<List<UserListEntity>, GetFollowersParams> {
  final FollowersRepository repository;

  GetFollowersUseCase(this.repository);

  @override
  Future<Either<Failure, List<UserListEntity>>> call(
    GetFollowersParams params,
  ) {
    return repository.getFollowers(
      userId: params.userId,
      currentUserId: params.currentUserId,
    );
  }
}

class GetFollowersParams {
  final String userId;
  final String? currentUserId;

  GetFollowersParams({required this.userId, this.currentUserId});
}
