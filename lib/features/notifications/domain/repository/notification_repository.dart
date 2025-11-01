import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';

/// Abstract repository for handling notifications.
abstract class NotificationsRepository {
  Future<Either<Failure, List<NotificationEntity>>> getPaginatedNotifications({
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  });
  Stream<Either<Failure, List<NotificationEntity>>> getNotificationsStream();
  Stream<Either<Failure, int>> getUnreadCountStream();
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead();
  Future<Either<Failure, void>> deleteNotifications(
    List<String> notificationIds,
  );
}
