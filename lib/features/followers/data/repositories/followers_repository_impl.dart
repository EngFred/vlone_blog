import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/followers/data/datasources/followers_remote_datasource.dart';
import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

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
  Future<Either<Failure, List<UserListEntity>>> getFollowers({
    required String userId,
    String? currentUserId,
  }) async {
    try {
      final userModels = await remoteDataSource.getFollowers(
        userId: userId,
        currentUserId: currentUserId,
      );
      return Right(userModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<UserListEntity>>> getFollowing({
    required String userId,
    String? currentUserId,
  }) async {
    try {
      final userModels = await remoteDataSource.getFollowing(
        userId: userId,
        currentUserId: currentUserId,
      );
      return Right(userModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> getFollowStatus({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final isFollowing = await remoteDataSource.getFollowStatus(
        followerId: followerId,
        followingId: followingId,
      );
      return Right(isFollowing);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
