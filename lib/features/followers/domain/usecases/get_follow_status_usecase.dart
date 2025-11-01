import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/repositories/followers_repository.dart';

class GetFollowStatusUseCase implements UseCase<bool, GetFollowStatusParams> {
  final FollowersRepository repository;

  GetFollowStatusUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(GetFollowStatusParams params) {
    return repository.getFollowStatus(
      followerId: params.followerId,
      followingId: params.followingId,
    );
  }
}

class GetFollowStatusParams {
  final String followerId;
  final String followingId;

  GetFollowStatusParams({required this.followerId, required this.followingId});
}
