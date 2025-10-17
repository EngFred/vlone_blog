import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/followers/data/datasources/followers_remote_datasource.dart';
import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class FollowersRepositoryImpl implements FollowersRepository {
  final FollowersRemoteDataSource remoteDataSource;

  FollowersRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, FollowerEntity>> followUser({
    required String followerId,
    required String followingId,
    required bool isFollowing,
  }) async {
    try {
      final followerModel = await remoteDataSource.followUser(
        followerId: followerId,
        followingId: followingId,
        isFollowing: isFollowing,
      );
      return Right(followerModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final profileModels = await remoteDataSource.getFollowers(
        userId: userId,
        page: page,
        limit: limit,
      );
      return Right(profileModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final profileModels = await remoteDataSource.getFollowing(
        userId: userId,
        page: page,
        limit: limit,
      );
      return Right(profileModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
