import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetPostParams {
  final String postId;
  final String currentUserId;

  const GetPostParams({required this.postId, required this.currentUserId});
}

class GetPostUseCase implements UseCase<PostEntity, GetPostParams> {
  final PostsRepository repository;

  const GetPostUseCase(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(GetPostParams params) {
    return repository.getPost(
      postId: params.postId,
      currentUserId: params.currentUserId,
    );
  }
}
