import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetPostUseCase implements UseCase<PostEntity, String> {
  final PostsRepository repository;

  GetPostUseCase(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(String postId) {
    return repository.getPost(postId);
  }
}
