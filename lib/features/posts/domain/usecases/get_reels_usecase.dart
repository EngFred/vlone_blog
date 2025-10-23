import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetReelsParams {
  final String currentUserId;

  const GetReelsParams({required this.currentUserId});
}

class GetReelsUseCase implements UseCase<List<PostEntity>, GetReelsParams> {
  final PostsRepository repository;

  const GetReelsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetReelsParams params) {
    return repository.getReels(currentUserId: params.currentUserId);
  }
}
