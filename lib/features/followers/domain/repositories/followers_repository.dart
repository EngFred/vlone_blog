import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

abstract class FollowersRepository {
  Future<Either<Failure, FollowerEntity>> followUser({
    required String followerId,
    required String followingId,
    required bool isFollowing, // To toggle
  });
  Future<Either<Failure, List<ProfileEntity>>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, List<ProfileEntity>>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  });
}
