import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

/// Use case for deleting an existing post by its ID.
///
/// Returns [Unit] upon successful deletion, or [Failure] on error.
class DeletePostUseCase implements UseCase<Unit, DeletePostParams> {
  final PostsRepository repository;

  DeletePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeletePostParams params) {
    return repository.deletePost(params.postId);
  }
}

/// Parameters required for [DeletePostUseCase].
class DeletePostParams {
  final String postId;

  DeletePostParams({required this.postId});
}
