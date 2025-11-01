import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetUserPostsParams {
  final String profileUserId;
  final String currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetUserPostsParams({
    required this.profileUserId,
    required this.currentUserId,
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });
}

class GetUserPostsUseCase
    implements UseCase<List<PostEntity>, GetUserPostsParams> {
  final PostsRepository repository;

  const GetUserPostsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetUserPostsParams params) {
    return repository.getUserPosts(
      profileUserId: params.profileUserId,
      currentUserId: params.currentUserId,
      pageSize: params.pageSize,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}
