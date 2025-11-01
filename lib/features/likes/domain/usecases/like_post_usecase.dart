import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/repository/likes_repository.dart';

class LikePostUseCase implements UseCase<Unit, LikePostParams> {
  final LikesRepository repository;

  LikePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(LikePostParams params) {
    return repository.likePost(
      postId: params.postId,
      userId: params.userId,
      isLiked: params.isLiked,
    );
  }
}

class LikePostParams {
  final String postId;
  final String userId;
  final bool isLiked;

  LikePostParams({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });
}
