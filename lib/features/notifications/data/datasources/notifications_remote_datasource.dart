import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/notifications/data/models/notification_model.dart';

class NotificationsRemoteDataSource {
  final SupabaseClient client;

  static const String _notificationsView = 'notifications_view';
  static const String _notificationsTable = 'notifications';

  NotificationsRemoteDataSource(this.client);

  /// Helper for normalizing the dynamic list response from a Postgres RPC function.
  List _normalizeRpcList(dynamic resp) {
    if (resp == null) return <dynamic>[];
    if (resp is List) return resp;
    if (resp is Map) return [resp];
    return <dynamic>[];
  }

  /// Fetches a paginated list of enriched notifications for a specific user using a Postgres RPC function.
  ///
  /// This method uses cursor-based pagination parameters (`lastCreatedAt`, `lastId`) for efficient loading.
  Future<List<NotificationModel>> getPaginatedNotifications({
    required String userId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      AppLogger.info(
        'Fetching paginated notifications for user: $userId with pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
      );

      final response = await client.rpc(
        'get_notifications_for_user',
        params: {
          'p_recipient_id': userId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );

      final rows = _normalizeRpcList(response);
      if (rows.isEmpty) return [];

      AppLogger.info('Fetched ${rows.length} notifications via RPC');

      return rows
          .map((map) => NotificationModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching paginated notifications: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Provides a broadcast stream of the current user's notifications.
  ///
  /// It **seeds** initial data by querying the enriched `notifications_view` and then
  /// subscribes to **real-time changes** on the underlying `notifications` table.
  /// On any real-time event, it refetches the entire view to ensure all foreign key joins (e.g., actor details) are up to date.
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
        // 1. Seeding initial data.
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
          if (!controller.isClosed) {
            controller.addError(ServerException(e.toString()));
          }
          // Continue to subscribe to real-time events even if seeding fails.
        }

        // 2. Subscribing to real-time events.
        try {
          final realtime = client
              .from(_notificationsTable)
              .stream(primaryKey: ['id'])
              .eq('recipient_id', userId);

          sub = realtime.listen(
            (payloadList) async {
              try {
                // On any event (Insert/Update/Delete), refetch the canonical VIEW to get enriched data.
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
          // Exposing the error to listeners if the subscription setup failed.
          if (!controller.isClosed && controller.hasListener) {
            controller.addError(ServerException(e.toString()));
          }
        }
      },
      onCancel: () async {
        // Small delay to prevent resource flapping.
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

  /// Provides a real-time broadcast stream of the current user's unread notification count.
  ///
  /// This streams **seeds** the initial count and refreshes on any real-time table event.
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
            // Counting notifications where 'read_at' is NULL.
            final resp = await client
                .from(_notificationsTable)
                .select('id')
                .eq('recipient_id', userId)
                .filter(
                  'read_at',
                  'is',
                  null,
                ); // Using .filter for 'is' operator.

            // ignore: dead_code
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

        // 1. Initial count fetch.
        await fetchAndAdd();

        // 2. Subscribing to table changes to refresh the count on any event.
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

  /// Marks a single notification as read by updating its `read_at` timestamp.
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

  /// Marks all unread notifications for the current user as read.
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
          .filter(
            'read_at',
            'is',
            null,
          ); // Targeting only unread notifications.

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
  ///
  /// The deletion is also filtered by `recipient_id` to ensure users can only delete their own notifications.
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
          .filter('id', 'in', notificationIds) // Filtering by notification IDs.
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
