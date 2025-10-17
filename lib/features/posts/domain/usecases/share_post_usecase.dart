import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class SharePostUseCase implements UseCase<Unit, SharePostParams> {
  final PostsRepository repository;

  SharePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SharePostParams params) {
    return repository.sharePost(postId: params.postId);
  }
}

class SharePostParams {
  final String postId;

  SharePostParams({required this.postId});
}
