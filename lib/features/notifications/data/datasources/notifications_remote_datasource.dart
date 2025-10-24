import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/notifications/data/models/notification_model.dart';

class NotificationsRemoteDataSource {
  final SupabaseClient client;

  static const String _notificationsView = 'notifications_view';
  static const String _notificationsTable = 'notifications';

  NotificationsRemoteDataSource(this.client);

  /// Stream real-time notifications for the current user
  Stream<List<NotificationModel>> getNotificationsStream() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.warning('Cannot stream notifications: User not logged in.');
      return Stream.error(const ServerException('User not authenticated.'));
    }

    AppLogger.info('Subscribing to notifications stream for user: $userId');

    final realtimeStream = client
        .from(_notificationsView)
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    return realtimeStream
        .map((rows) {
          final notifications = rows
              .map((map) => NotificationModel.fromMap(map))
              .toList();
          AppLogger.info(
            'Realtime stream received ${notifications.length} notifications.',
          );
          return notifications;
        })
        .handleError((e, stackTrace) {
          AppLogger.error(
            'Realtime stream error for notifications: $e',
            error: e,
            stackTrace: stackTrace,
          );
          throw ServerException(e.toString());
        });
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('User not authenticated.');
    }

    AppLogger.info('Marking notification ID $notificationId as read.');
    try {
      await client
          .from(_notificationsTable)
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId)
          .eq('recipient_id', userId);

      AppLogger.info(
        'Notification ID $notificationId marked as read successfully.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to mark notification ID $notificationId as read, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  /// Mark all unread notifications as read
  Future<void> markAllAsRead() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('User not authenticated.');
    }

    AppLogger.info(
      'Marking all unread notifications for user $userId as read.',
    );
    try {
      await client
          .from(_notificationsTable)
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('recipient_id', userId)
          .filter('read_at', 'is', null);

      AppLogger.info('All unread notifications marked as read successfully.');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to mark all notifications as read, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }
}
