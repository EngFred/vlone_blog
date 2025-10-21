import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetReelsUseCase implements UseCase<List<PostEntity>, NoParams> {
  final PostsRepository repository;
  GetReelsUseCase(this.repository);
  @override
  Future<Either<Failure, List<PostEntity>>> call(NoParams params) {
    return repository.getReels();
  }
}
