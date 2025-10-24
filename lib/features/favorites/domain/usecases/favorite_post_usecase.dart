import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';

class FavoritePostUseCase implements UseCase<Unit, FavoritePostParams> {
  final FavoritesRepository repository;

  FavoritePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(FavoritePostParams params) {
    return repository.favoritePost(
      postId: params.postId,
      userId: params.userId,
      isFavorited: params.isFavorited,
    );
  }
}

class FavoritePostParams extends Equatable {
  final String postId;
  final String userId;
  final bool isFavorited;

  const FavoritePostParams({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}
