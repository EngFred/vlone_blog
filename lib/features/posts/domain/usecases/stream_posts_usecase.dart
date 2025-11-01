import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

/// Use case for streaming new posts in real-time
class StreamNewPostsUseCase implements StreamUseCase<PostEntity, NoParams> {
  final PostsRepository repository;

  StreamNewPostsUseCase(this.repository);

  @override
  Stream<Either<Failure, PostEntity>> call(NoParams params) {
    return repository.streamNewPosts();
  }
}

/// Use case for streaming post updates (counts)
class StreamPostUpdatesUseCase
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  final PostsRepository repository;

  StreamPostUpdatesUseCase(this.repository);

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params) {
    return repository.streamPostUpdates();
  }
}
