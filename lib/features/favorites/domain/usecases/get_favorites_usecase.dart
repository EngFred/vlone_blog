import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class GetFavoritesUseCase
    implements UseCase<List<PostEntity>, GetFavoritesParams> {
  final FavoritesRepository repository;

  GetFavoritesUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFavoritesParams params) {
    return repository.getFavorites(userId: params.userId);
  }
}

class GetFavoritesParams extends Equatable {
  final String userId;

  const GetFavoritesParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}
