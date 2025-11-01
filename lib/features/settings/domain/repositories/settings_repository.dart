import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';

abstract class SettingsRepository {
  Future<Either<Failure, String?>> getThemeMode();
  Future<Either<Failure, void>> saveThemeMode(String mode);
}
