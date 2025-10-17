import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';

class FollowUserUseCase implements UseCase<FollowerEntity, FollowUserParams> {
  final FollowersRepository repository;

  FollowUserUseCase(this.repository);

  @override
  Future<Either<Failure, FollowerEntity>> call(FollowUserParams params) {
    return repository.followUser(
      followerId: params.followerId,
      followingId: params.followingId,
      isFollowing: params.isFollowing,
    );
  }
}

class FollowUserParams {
  final String followerId;
  final String followingId;
  final bool isFollowing;

  FollowUserParams({
    required this.followerId,
    required this.followingId,
    required this.isFollowing,
  });
}
