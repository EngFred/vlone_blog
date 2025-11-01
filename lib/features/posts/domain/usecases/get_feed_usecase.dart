import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetFeedParams {
  final String currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetFeedParams({
    required this.currentUserId,
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });
}

class GetFeedUseCase implements UseCase<List<PostEntity>, GetFeedParams> {
  final PostsRepository repository;

  const GetFeedUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFeedParams params) {
    return repository.getFeed(
      currentUserId: params.currentUserId,
      pageSize: params.pageSize,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}
