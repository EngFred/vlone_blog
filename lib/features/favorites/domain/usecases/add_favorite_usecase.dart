import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:vlone_blog_app/features/favorites/domain/repositories/favorites_repository.dart';

class AddFavoriteUseCase implements UseCase<FavoriteEntity, AddFavoriteParams> {
  final FavoritesRepository repository;

  AddFavoriteUseCase(this.repository);

  @override
  Future<Either<Failure, FavoriteEntity>> call(AddFavoriteParams params) {
    return repository.addFavorite(
      postId: params.postId,
      userId: params.userId,
      isFavorited: params.isFavorited,
    );
  }
}

class AddFavoriteParams {
  final String postId;
  final String userId;
  final bool isFavorited;

  AddFavoriteParams({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });
}
