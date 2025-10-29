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
      pageSize: params.pageSize,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}

class GetFollowersParams {
  final String userId;
  final String? currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  GetFollowersParams({
    required this.userId,
    this.currentUserId,
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });
}
