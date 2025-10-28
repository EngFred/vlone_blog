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

  /// Returns a broadcast stream giving the current user's notifications (newest-first).
  /// Seeds initial data from `_notificationsView` and listens to table changes on `_notificationsTable`.
  Stream<List<NotificationModel>> getNotificationsStream() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.warning('Cannot stream notifications: User not logged in.');
      return Stream.error(const ServerException('User not authenticated.'));
    }

    AppLogger.info(
      'Creating notifications stream controller for user: $userId',
    );

    late final StreamController<List<NotificationModel>> controller;
    StreamSubscription<dynamic>? sub;

    controller = StreamController<List<NotificationModel>>.broadcast(
      onListen: () async {
        // Seed initial notifications by querying the view (provides actor_username, actor_image_url, etc.)
        try {
          final initialResp = await client
              .from(_notificationsView)
              .select()
              .eq('recipient_id', userId)
              .order('created_at', ascending: false);

          final rows = (initialResp is List) ? initialResp : <dynamic>[];
          final initial = rows
              .map((r) => NotificationModel.fromMap(r as Map<String, dynamic>))
              .toList();

          if (!controller.isClosed) controller.add(initial);
          AppLogger.info(
            'Seeded ${initial.length} notifications for user $userId',
          );
        } catch (e, st) {
          AppLogger.error(
            'Failed to seed notifications: $e',
            error: e,
            stackTrace: st,
          );
          if (!controller.isClosed)
            controller.addError(ServerException(e.toString()));
          // still continue to subscribe to realtime to recover
        }

        // Subscribe to actual table realtime events and refetch view on changes
        try {
          final realtime = client
              .from(_notificationsTable)
              .stream(primaryKey: ['id'])
              .eq('recipient_id', userId);

          sub = realtime.listen(
            (payloadList) async {
              try {
                // On any event for this recipient, refetch the canonical view to pick up joins/metadata
                final resp = await client
                    .from(_notificationsView)
                    .select()
                    .eq('recipient_id', userId)
                    .order('created_at', ascending: false);

                final rows = (resp is List) ? resp : <dynamic>[];
                final items = rows
                    .map(
                      (r) =>
                          NotificationModel.fromMap(r as Map<String, dynamic>),
                    )
                    .toList();

                if (!controller.isClosed) controller.add(items);
              } catch (e, st) {
                AppLogger.error(
                  'Failed to refresh notifications after realtime event: $e',
                  error: e,
                  stackTrace: st,
                );
                if (!controller.isClosed && controller.hasListener) {
                  controller.addError(ServerException(e.toString()));
                }
              }
            },
            onError: (err, st) {
              AppLogger.error(
                'Notifications realtime subscription error: $err',
                error: err,
                stackTrace: st,
              );
              if (!controller.isClosed && controller.hasListener) {
                controller.addError(ServerException(err.toString()));
              }
            },
            cancelOnError: false,
          );
        } catch (e, st) {
          AppLogger.error(
            'Failed to subscribe to notifications realtime: $e',
            error: e,
            stackTrace: st,
          );
          // Already seeded earlier; expose the error to listeners
          if (!controller.isClosed && controller.hasListener) {
            controller.addError(ServerException(e.toString()));
          }
        }
      },
      onCancel: () async {
        // small delay to avoid flapping
        await Future.delayed(const Duration(milliseconds: 50));
        if (!controller.hasListener) {
          AppLogger.info(
            'No more notification listeners for user; cancelling subscription.',
          );
          try {
            await sub?.cancel();
          } catch (_) {}
          if (!controller.isClosed) await controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Stream unread count (derived) for the current user.
  /// Seeds with a COUNT(*) query and refreshes on table events.
  Stream<int> getUnreadCountStream() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.warning('Cannot stream unread count: User not logged in.');
      return Stream.error(const ServerException('User not authenticated.'));
    }

    AppLogger.info('Creating unread-count stream for user: $userId');

    late final StreamController<int> ctrl;
    StreamSubscription<dynamic>? sub;

    ctrl = StreamController<int>.broadcast(
      onListen: () async {
        Future<void> fetchAndAdd() async {
          try {
            final resp = await client
                .from(_notificationsTable)
                .select('id')
                .eq('recipient_id', userId)
                // FIX: Use .filter to avoid Dart keyword conflict with .is
                .filter('read_at', 'is', null);

            final count = (resp is List) ? resp.length : 0;
            if (!ctrl.isClosed) ctrl.add(count);
          } catch (e, st) {
            AppLogger.error(
              'Failed to fetch unread count: $e',
              error: e,
              stackTrace: st,
            );
            if (!ctrl.isClosed && ctrl.hasListener) {
              ctrl.addError(ServerException(e.toString()));
            }
          }
        }

        // initial
        await fetchAndAdd();

        // subscribe to table changes for this recipient and refresh on events
        try {
          final realtime = client
              .from(_notificationsTable)
              .stream(primaryKey: ['id'])
              .eq('recipient_id', userId);

          sub = realtime.listen(
            (_) async {
              await fetchAndAdd();
            },
            onError: (err, st) {
              AppLogger.error(
                'Unread count realtime error: $err',
                error: err,
                stackTrace: st,
              );
              if (!ctrl.isClosed && ctrl.hasListener) {
                ctrl.addError(ServerException(err.toString()));
              }
            },
            cancelOnError: false,
          );
        } catch (e, st) {
          AppLogger.error(
            'Failed to subscribe to unread-count realtime: $e',
            error: e,
            stackTrace: st,
          );
        }
      },
      onCancel: () async {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!ctrl.hasListener) {
          AppLogger.info(
            'No more unread-count listeners; cancelling subscription.',
          );
          try {
            await sub?.cancel();
          } catch (_) {}
          if (!ctrl.isClosed) await ctrl.close();
        }
      },
    );

    return ctrl.stream;
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
          // FIX: Use .filter to avoid Dart keyword conflict with .is
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
  Future<void> deleteNotifications(List<String> notificationIds) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('User not authenticated.');
    }
    if (notificationIds.isEmpty) {
      AppLogger.warning('Delete notifications called with empty list.');
      return;
    }

    AppLogger.info(
      'Deleting ${notificationIds.length} notifications for user $userId.',
    );
    try {
      await client
          .from(_notificationsTable)
          .delete()
          // FIX: Use .filter to avoid Dart keyword conflict with .in
          .filter('id', 'in', notificationIds)
          .eq('recipient_id', userId);

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
