import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';

/// Abstract repository for handling notifications.
abstract class NotificationsRepository {
  /// Subscribes to a real-time stream of notifications for the current user.
  ///
  /// Emits a new list of [NotificationEntity] on any change.
  /// Emits a [Failure] if the stream subscription fails.
  Stream<Either<Failure, List<NotificationEntity>>> getNotificationsStream();

  /// Subscribes to a real-time stream of unread notification count (int).
  ///
  /// Emits a new unread count whenever it changes.
  Stream<Either<Failure, int>> getUnreadCountStream();

  /// Marks a single notification as read.
  ///
  /// Returns [Right(null)] on success, or [Left(Failure)] on error.
  Future<Either<Failure, void>> markAsRead(String notificationId);

  /// Marks all unread notifications for the current user as read.
  ///
  /// Returns [Right(null)] on success, or [Left(Failure)] on error.
  Future<Either<Failure, void>> markAllAsRead();
}
