import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/settings/domain/repositories/settings_repository.dart';

class SaveThemeMode implements UseCase<void, String> {
  final SettingsRepository repository;

  SaveThemeMode(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await repository.saveThemeMode(params);
  }
}
