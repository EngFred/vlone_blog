import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

class DeleteNotificationsUseCase
    implements UseCase<void, DeleteNotificationsParams> {
  final NotificationsRepository repository;

  DeleteNotificationsUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteNotificationsParams params) async {
    return await repository.deleteNotifications(params.notificationIds);
  }
}

class DeleteNotificationsParams extends Equatable {
  final List<String> notificationIds;

  const DeleteNotificationsParams(this.notificationIds);

  @override
  List<Object?> get props => [notificationIds];
}
