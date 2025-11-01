import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/settings/domain/repositories/settings_repository.dart';

class GetThemeMode implements UseCase<String?, NoParams> {
  final SettingsRepository repository;

  GetThemeMode(this.repository);

  @override
  Future<Either<Failure, String?>> call(NoParams params) async {
    return await repository.getThemeMode();
  }
}
