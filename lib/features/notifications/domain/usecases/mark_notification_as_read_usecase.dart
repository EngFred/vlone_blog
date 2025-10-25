import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

/// Use case to mark a single notification as read.
/// Takes the notification ID as a [String] parameter.
class MarkAsReadUseCase implements UseCase<void, String> {
  final NotificationsRepository repository;

  MarkAsReadUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.markAsRead(params);
  }
}
