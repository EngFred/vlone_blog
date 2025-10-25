import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_notifications_stream_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_unread_count_stream_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_all_as_read_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final GetNotificationsStreamUseCase _getNotificationsStreamUseCase;
  final GetUnreadCountStreamUseCase _getUnreadCountStreamUseCase;
  final MarkAsReadUseCase _markAsReadUseCase;
  final MarkAllAsReadUseCase _markAllAsReadUseCase;

  StreamSubscription<Either<Failure, List<NotificationEntity>>>?
  _notificationsSubscription;

  StreamSubscription<Either<Failure, int>>? _unreadCountSubscription;

  // Keep latest values so we can combine them when either updates.
  List<NotificationEntity> _latestNotifications = [];
  int _latestUnreadCount = 0;

  NotificationsBloc({
    required GetNotificationsStreamUseCase getNotificationsStreamUseCase,
    required GetUnreadCountStreamUseCase getUnreadCountStreamUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required MarkAllAsReadUseCase markAllAsReadUseCase,
  }) : _getNotificationsStreamUseCase = getNotificationsStreamUseCase,
       _getUnreadCountStreamUseCase = getUnreadCountStreamUseCase,
       _markAsReadUseCase = markAsReadUseCase,
       _markAllAsReadUseCase = markAllAsReadUseCase,
       super(NotificationsInitial()) {
    on<NotificationsSubscribeStream>(_onSubscribeStream);
    on<NotificationsSubscribeUnreadCountStream>(_onSubscribeUnreadCountStream);
    on<_NotificationsStreamUpdated>(_onStreamUpdated);
    on<_UnreadCountStreamUpdated>(_onUnreadCountUpdated);
    on<NotificationsMarkOneAsRead>(_onMarkOneAsRead);
    on<NotificationsMarkAllAsRead>(_onMarkAllAsRead);
  }

  /// Handles the initial subscription event for the notifications list.
  void _onSubscribeStream(
    NotificationsSubscribeStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info('Subscribing to notifications stream...');
    // Emit Loading state only if we are in the Initial state
    if (state is NotificationsInitial) {
      emit(NotificationsLoading());
    }

    // Cancel any existing subscription before creating a new one
    _notificationsSubscription?.cancel();

    _notificationsSubscription = _getNotificationsStreamUseCase(NoParams())
        .listen(
          (update) {
            // Add an internal event to process the stream update
            add(_NotificationsStreamUpdated(update));
          },
          onError: (error) {
            AppLogger.error('Notifications stream error: $error', error: error);
            add(
              _NotificationsStreamUpdated(
                Left(ServerFailure('Stream error: ${error.toString()}')),
              ),
            );
          },
        );

    // Also ensure the unread count stream is subscribed so UI gets immediate count updates
    add(NotificationsSubscribeUnreadCountStream());
  }

  /// Handles subscribing to the unread count stream.
  void _onSubscribeUnreadCountStream(
    NotificationsSubscribeUnreadCountStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info('Subscribing to unread count stream...');
    _unreadCountSubscription?.cancel();

    _unreadCountSubscription = _getUnreadCountStreamUseCase(NoParams()).listen(
      (update) {
        add(_UnreadCountStreamUpdated(update));
      },
      onError: (error) {
        AppLogger.error('Unread count stream error: $error', error: error);
        add(
          _UnreadCountStreamUpdated(
            Left(
              ServerFailure('Unread count stream error: ${error.toString()}'),
            ),
          ),
        );
      },
    );
  }

  /// Handles new data batches from the notifications stream.
  void _onStreamUpdated(
    _NotificationsStreamUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    event.update.fold(
      (failure) {
        AppLogger.error('Notifications stream failed: ${failure.message}');
        emit(
          NotificationsError(
            ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (notifications) {
        AppLogger.info(
          'Notifications stream updated with ${notifications.length} items.',
        );
        _latestNotifications = notifications;
        // If we already have a latest unread count from its stream use it,
        // otherwise compute as fallback.
        final int computedUnread = _latestUnreadCount > 0
            ? _latestUnreadCount
            : notifications.where((n) => !n.isRead).length;
        emit(
          NotificationsLoaded(
            notifications: notifications,
            unreadCount: computedUnread,
          ),
        );
      },
    );
  }

  /// Handles unread count updates from the count stream.
  void _onUnreadCountUpdated(
    _UnreadCountStreamUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    event.update.fold(
      (failure) {
        AppLogger.error('Unread count stream failed: ${failure.message}');
        // If we have notifications in memory, we keep showing them but may
        // surface an error state if you prefer. Here we log and emit error.
        emit(
          NotificationsError(
            ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (count) {
        AppLogger.info('Unread count stream updated: $count');
        _latestUnreadCount = count;
        // Emit loaded with latest known notifications (or empty list if none)
        emit(
          NotificationsLoaded(
            notifications: _latestNotifications,
            unreadCount: _latestUnreadCount,
          ),
        );
      },
    );
  }

  /// Handles marking a single notification as read.
  void _onMarkOneAsRead(
    NotificationsMarkOneAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking notification ${event.notificationId} as read.');
    final result = await _markAsReadUseCase(event.notificationId);

    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to mark notification ${event.notificationId} as read: ${failure.message}',
        );
        // Optionally emit or show UI feedback
      },
      (_) {
        AppLogger.info(
          'Notification ${event.notificationId} marked as read via API.',
        );
      },
    );
  }

  /// Handles marking all notifications as read.
  void _onMarkAllAsRead(
    NotificationsMarkAllAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking all notifications as read.');
    final result = await _markAllAsReadUseCase(NoParams());

    result.fold(
      (failure) {
        AppLogger.error('Failed to mark all as read: ${failure.message}');
      },
      (_) {
        AppLogger.info('All notifications marked as read via API.');
      },
    );
  }

  @override
  Future<void> close() {
    AppLogger.info(
      'Closing NotificationsBloc and canceling stream subscriptions.',
    );
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    return super.close();
  }
}
