import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class DeletePostUseCase implements UseCase<Unit, DeletePostParams> {
  final PostsRepository repository;

  DeletePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeletePostParams params) {
    return repository.deletePost(params.postId);
  }
}

class DeletePostParams {
  final String postId;

  DeletePostParams({required this.postId});
}
