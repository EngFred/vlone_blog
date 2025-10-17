import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/favorites/domain/repositories/favorites_repository.dart';

class GetFavoritesUseCase
    implements UseCase<List<PostEntity>, GetFavoritesParams> {
  final FavoritesRepository repository;

  GetFavoritesUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFavoritesParams params) {
    return repository.getFavorites(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetFavoritesParams {
  final String userId;
  final int page;
  final int limit;

  GetFavoritesParams({required this.userId, this.page = 1, this.limit = 20});
}
