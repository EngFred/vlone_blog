import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetReelsParams {
  final String currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetReelsParams({
    required this.currentUserId,
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });
}

class GetReelsUseCase implements UseCase<List<PostEntity>, GetReelsParams> {
  final PostsRepository repository;

  const GetReelsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetReelsParams params) {
    return repository.getReels(
      currentUserId: params.currentUserId,
      pageSize: params.pageSize,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}
