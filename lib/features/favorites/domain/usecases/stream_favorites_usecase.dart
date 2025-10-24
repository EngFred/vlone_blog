import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/repository/favorites_repository.dart';

/// Use case for streaming favorite events
class StreamFavoritesUseCase
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  final FavoritesRepository repository;

  StreamFavoritesUseCase(this.repository);

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params) {
    return repository.streamFavorites();
  }
}
