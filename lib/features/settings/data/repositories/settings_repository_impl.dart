import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:vlone_blog_app/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, String?>> getThemeMode() async {
    try {
      final mode = await localDataSource.getThemeMode();
      return Right(mode);
    } catch (e) {
      return Left(CacheFailure('Failed to get theme mode from cache: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveThemeMode(String mode) async {
    try {
      await localDataSource.saveThemeMode(mode);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save theme mode to cache: $e'));
    }
  }
}
