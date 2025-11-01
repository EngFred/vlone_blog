import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

/// Use case to mark all notifications as read.
/// Takes [NoParams] as a parameter.
class MarkAllAsReadUseCase implements UseCase<void, NoParams> {
  final NotificationsRepository repository;

  MarkAllAsReadUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.markAllAsRead();
  }
}
