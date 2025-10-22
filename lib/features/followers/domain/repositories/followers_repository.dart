import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

abstract class FollowersRepository {
  Future<Either<Failure, FollowerEntity>> followUser({
    required String followerId,
    required String followingId,
    required bool isFollowing,
  });

  Future<Either<Failure, List<UserListEntity>>> getFollowers({
    required String userId,
    String? currentUserId,
  });

  Future<Either<Failure, List<UserListEntity>>> getFollowing({
    required String userId,
    String? currentUserId,
  });

  Future<Either<Failure, bool>> getFollowStatus({
    required String followerId,
    required String followingId,
  });
}
