import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/notifications/data/models/notification_model.dart';

class NotificationsRemoteDataSource {
  final SupabaseClient client;

  static const String _notificationsView = 'notifications_view';
  static const String _notificationsTable = 'notifications';
  static const String _unreadCountTable = 'unread_notification_count';

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

  /// Stream the unread notification count for the current user.
  Stream<int> getUnreadCountStream() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.warning('Cannot stream unread count: User not logged in.');
      return Stream.error(const ServerException('User not authenticated.'));
    }

    AppLogger.info('Subscribing to unread count stream for user: $userId');

    final realtimeStream = client
        .from(_unreadCountTable)
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId);

    return realtimeStream
        .map((rows) {
          try {
            if (rows.isEmpty) {
              return 0;
            }
            final first = rows.first;
            final rawCount = first['unread_count'];
            if (rawCount == null) return 0;
            if (rawCount is int) return rawCount;
            return int.tryParse(rawCount.toString()) ?? 0;
          } catch (e, st) {
            AppLogger.error(
              'Failed parsing unread count row: $e',
              error: e,
              stackTrace: st,
            );
            throw ServerException('Failed to parse unread count.');
          }
        })
        .handleError((e, stackTrace) {
          AppLogger.error(
            'Realtime stream error for unread count: $e',
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

  /// Deletes one or more notifications by their IDs.
  /// Your RLS policy ensures the user can only delete their own notifications.
  Future<void> deleteNotifications(List<String> notificationIds) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('User not authenticated.');
    }
    if (notificationIds.isEmpty) {
      AppLogger.warning('Delete notifications called with empty list.');
      return;
    }

    AppLogger.info('Deleting ${notificationIds.length} notifications.');
    try {
      await client
          .from(_notificationsTable)
          .delete()
          .inFilter('id', notificationIds) //
          .eq(
            'recipient_id',
            userId,
          ); // RLS already handles this, but .eq() is a good safeguard.

      AppLogger.info(
        'Successfully deleted ${notificationIds.length} notifications.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to delete notifications, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }
}
