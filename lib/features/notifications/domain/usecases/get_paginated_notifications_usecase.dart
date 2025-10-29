import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/repository/notification_repository.dart';

class GetPaginatedNotificationsUseCase
    implements
        UseCase<List<NotificationEntity>, GetPaginatedNotificationsParams> {
  final NotificationsRepository repository;

  GetPaginatedNotificationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<NotificationEntity>>> call(
    GetPaginatedNotificationsParams params,
  ) async {
    return await repository.getPaginatedNotifications(
      pageSize: params.pageSize,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
    );
  }
}

class GetPaginatedNotificationsParams extends Equatable {
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetPaginatedNotificationsParams({
    this.pageSize = 20,
    this.lastCreatedAt,
    this.lastId,
  });

  @override
  List<Object?> get props => [pageSize, lastCreatedAt, lastId];
}
