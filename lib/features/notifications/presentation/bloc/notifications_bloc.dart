import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/delete_notifications_usecase.dart';
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
  final DeleteNotificationsUseCase _deleteNotificationsUseCase;

  // Keep legacy direct subscriptions for backward compatibility (optional)
  StreamSubscription<Either<Failure, List<NotificationEntity>>>?
  _notificationsSubscription;
  StreamSubscription<Either<Failure, int>>? _unreadCountSubscription;

  // Subscriptions to the RealtimeService broadcast streams
  StreamSubscription<List<NotificationEntity>>? _rtNotificationsSub;
  StreamSubscription<int>? _rtUnreadCountSub;

  // RealtimeService (injected)
  final RealtimeService realtimeService;

  NotificationsBloc({
    required GetNotificationsStreamUseCase getNotificationsStreamUseCase,
    required GetUnreadCountStreamUseCase getUnreadCountStreamUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required MarkAllAsReadUseCase markAllAsReadUseCase,
    required DeleteNotificationsUseCase deleteNotificationsUseCase,
    required this.realtimeService,
  }) : _getNotificationsStreamUseCase = getNotificationsStreamUseCase,
       _getUnreadCountStreamUseCase = getUnreadCountStreamUseCase,
       _markAsReadUseCase = markAsReadUseCase,
       _markAllAsReadUseCase = markAllAsReadUseCase,
       _deleteNotificationsUseCase = deleteNotificationsUseCase,
       super(NotificationsInitial()) {
    on<NotificationsSubscribeStream>(_onSubscribeStream);
    on<NotificationsSubscribeUnreadCountStream>(_onSubscribeUnreadCountStream);
    on<_NotificationsStreamUpdated>(_onStreamUpdated);
    on<_UnreadCountStreamUpdated>(_onUnreadCountUpdated);
    on<NotificationsMarkOneAsRead>(_onMarkOneAsRead);
    on<NotificationsMarkAllAsRead>(_onMarkAllAsRead);

    on<NotificationsDeleteOne>(_onDeleteOne);
    on<NotificationsDeleteSelected>(_onDeleteSelected);
    on<NotificationsEnterSelectionMode>(_onEnterSelectionMode);
    on<NotificationsExitSelectionMode>(_onExitSelectionMode);
    on<NotificationsToggleSelection>(_onToggleSelection);
  }

  void _onSubscribeStream(
    NotificationsSubscribeStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info(
      'Subscribing to notifications stream (NotificationsBloc)...',
    );
    if (state is NotificationsInitial) {
      emit(NotificationsLoading());
    }

    // Legacy: still subscribe via usecase in case there are differences
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _getNotificationsStreamUseCase(NoParams())
        .listen(
          (update) => add(_NotificationsStreamUpdated(update)),
          onError: (error) {
            AppLogger.error('Notifications stream error: $error', error: error);
            add(
              _NotificationsStreamUpdated(
                Left(ServerFailure('Stream error: ${error.toString()}')),
              ),
            );
          },
        );

    // Preferred: subscribe to RealtimeService broadcast for unified flow
    _rtNotificationsSub?.cancel();
    _rtNotificationsSub = realtimeService.onNotificationsBatch.listen(
      (notifications) {
        try {
          // Wrap payload into Right and reuse the same internal update handler
          add(_NotificationsStreamUpdated(Right(notifications)));
        } catch (e) {
          AppLogger.error(
            'Realtime notifications payload handling failed: $e',
            error: e,
          );
        }
      },
      onError: (err) {
        AppLogger.error(
          'RealtimeService.onNotificationsBatch error: $err',
          error: err,
        );
        // Forward an error update so _onStreamUpdated can produce a NotificationsError state
        add(_NotificationsStreamUpdated(Left(ServerFailure(err.toString()))));
      },
    );

    // Also subscribe to unread count stream
    add(NotificationsSubscribeUnreadCountStream());
  }

  /// Handles subscribing to the unread count stream.
  void _onSubscribeUnreadCountStream(
    NotificationsSubscribeUnreadCountStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info('Subscribing to unread count stream...');

    // Legacy subscription
    _unreadCountSubscription?.cancel();
    _unreadCountSubscription = _getUnreadCountStreamUseCase(NoParams()).listen(
      (update) => add(_UnreadCountStreamUpdated(update)),
      onError: (error) {
        AppLogger.error(
          'Unread count stream error (legacy): $error',
          error: error,
        );
        add(
          _UnreadCountStreamUpdated(
            Left(
              ServerFailure('Unread count stream error: ${error.toString()}'),
            ),
          ),
        );
      },
    );

    // Preferred: RealtimeService
    _rtUnreadCountSub?.cancel();
    _rtUnreadCountSub = realtimeService.onUnreadCount.listen(
      (count) {
        try {
          add(_UnreadCountStreamUpdated(Right(count)));
        } catch (e) {
          AppLogger.error(
            'Realtime unread count handling failed: $e',
            error: e,
          );
        }
      },
      onError: (err) {
        AppLogger.error(
          'RealtimeService.onUnreadCount error: $err',
          error: err,
        );
        add(_UnreadCountStreamUpdated(Left(ServerFailure(err.toString()))));
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

        final List<NotificationEntity> entityList = List.from(notifications);

        if (state is NotificationsLoaded) {
          final currentState = state as NotificationsLoaded;
          emit(
            currentState.copyWith(
              notifications: entityList,
              selectedNotificationIds: currentState.selectedNotificationIds
                  .where((id) => entityList.any((n) => n.id == id))
                  .toSet(),
            ),
          );
        } else {
          emit(NotificationsLoaded(notifications: entityList, unreadCount: 0));
        }
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
        emit(
          NotificationsError(
            ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (count) {
        AppLogger.info('Unread count stream updated: $count');
        if (state is NotificationsLoaded) {
          final currentState = state as NotificationsLoaded;
          emit(currentState.copyWith(unreadCount: count));
        } else if (state is! NotificationsError) {
          emit(NotificationsLoaded(notifications: [], unreadCount: count));
        }
      },
    );
  }

  /// Handles marking a single notification as read.
  Future<void> _onMarkOneAsRead(
    NotificationsMarkOneAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking notification ${event.notificationId} as read.');

    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    final item = currentState.notifications.firstWhere(
      (n) => n.id == event.notificationId,
      orElse: () => NotificationEntity.empty,
    );

    if (item.id.isEmpty || item.isRead) {
      final result = await _markAsReadUseCase(event.notificationId);
      result.fold(
        (failure) => AppLogger.error(
          'Failed to mark (already read) notification: ${failure.message}',
        ),
        (_) => AppLogger.info('Notification mark-as-read confirmed via API.'),
      );
      return;
    }

    final updatedList = currentState.notifications.map((n) {
      if (n.id == event.notificationId) return n.copyWith(isRead: true);
      return n;
    }).toList();

    final newUnreadCount = (currentState.unreadCount - 1).clamp(0, 9999);

    emit(
      currentState.copyWith(
        notifications: updatedList,
        unreadCount: newUnreadCount,
      ),
    );

    final result = await _markAsReadUseCase(event.notificationId);
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to mark notification ${event.notificationId} as read: ${failure.message}',
        );
        emit(currentState);
      },
      (_) {
        AppLogger.info(
          'Notification ${event.notificationId} marked as read via API.',
        );
      },
    );
  }

  /// Handles marking all notifications as read.
  Future<void> _onMarkAllAsRead(
    NotificationsMarkAllAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking all notifications as read.');
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    if (currentState.unreadCount == 0) return;

    final updatedList = currentState.notifications
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();

    emit(currentState.copyWith(notifications: updatedList, unreadCount: 0));

    final result = await _markAllAsReadUseCase(NoParams());
    result.fold((failure) {
      AppLogger.error('Failed to mark all as read: ${failure.message}');
      emit(currentState);
    }, (_) => AppLogger.info('All notifications marked as read via API.'));
  }

  /// Handles deleting a single notification.
  Future<void> _onDeleteOne(
    NotificationsDeleteOne event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    final NotificationEntity deletedItem;
    try {
      deletedItem = currentState.notifications.firstWhere(
        (n) => n.id == event.notificationId,
      );
    } catch (e) {
      AppLogger.error(
        'Item ${event.notificationId} not found in state for deletion.',
      );
      return;
    }

    emit(currentState.copyWith(isDeleting: true));

    final result = await _deleteNotificationsUseCase(
      DeleteNotificationsParams([event.notificationId]),
    );
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to delete notification ${event.notificationId}: ${failure.message}',
        );
        emit(currentState.copyWith(isDeleting: false));
      },
      (_) {
        AppLogger.info('Notification ${event.notificationId} deleted via API.');

        final updatedList = currentState.notifications
            .where((n) => n.id != event.notificationId)
            .toList();
        final newSelectedIds = Set<String>.from(
          currentState.selectedNotificationIds,
        )..remove(event.notificationId);

        int newUnreadCount = currentState.unreadCount;
        if (!deletedItem.isRead)
          newUnreadCount = (currentState.unreadCount - 1).clamp(0, 9999);

        emit(
          currentState.copyWith(
            isDeleting: false,
            notifications: updatedList,
            selectedNotificationIds: newSelectedIds,
            isSelectionMode: newSelectedIds.isNotEmpty,
            unreadCount: newUnreadCount,
          ),
        );
      },
    );
  }

  /// Handles deleting selected notifications.
  Future<void> _onDeleteSelected(
    NotificationsDeleteSelected event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    final idsToDelete = currentState.selectedNotificationIds;
    if (idsToDelete.isEmpty) {
      emit(currentState.copyWith(isSelectionMode: false));
      return;
    }

    emit(currentState.copyWith(isDeleting: true));

    final result = await _deleteNotificationsUseCase(
      DeleteNotificationsParams(idsToDelete.toList()),
    );
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to delete ${idsToDelete.length} notifications: ${failure.message}',
        );
        emit(currentState.copyWith(isDeleting: false));
      },
      (_) {
        AppLogger.info('${idsToDelete.length} notifications deleted via API.');

        final updatedList = currentState.notifications
            .where((n) => !idsToDelete.contains(n.id))
            .toList();

        int unreadDeletedCount = 0;
        for (final n in currentState.notifications) {
          if (idsToDelete.contains(n.id) && !n.isRead) unreadDeletedCount++;
        }
        final newUnreadCount = (currentState.unreadCount - unreadDeletedCount)
            .clamp(0, 9999);

        emit(
          currentState.copyWith(
            isDeleting: false,
            notifications: updatedList,
            isSelectionMode: false,
            selectedNotificationIds: {},
            unreadCount: newUnreadCount,
          ),
        );
      },
    );
  }

  /// Selection mode handlers
  void _onEnterSelectionMode(
    NotificationsEnterSelectionMode event,
    Emitter<NotificationsState> emit,
  ) {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    emit(
      currentState.copyWith(
        isSelectionMode: true,
        selectedNotificationIds: {event.firstNotificationId},
      ),
    );
  }

  void _onExitSelectionMode(
    NotificationsExitSelectionMode event,
    Emitter<NotificationsState> emit,
  ) {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    emit(
      currentState.copyWith(
        isSelectionMode: false,
        selectedNotificationIds: {},
      ),
    );
  }

  void _onToggleSelection(
    NotificationsToggleSelection event,
    Emitter<NotificationsState> emit,
  ) {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    final newIds = Set<String>.from(currentState.selectedNotificationIds);
    if (newIds.contains(event.notificationId))
      newIds.remove(event.notificationId);
    else
      newIds.add(event.notificationId);

    emit(
      currentState.copyWith(
        selectedNotificationIds: newIds,
        isSelectionMode: newIds.isNotEmpty,
      ),
    );
  }

  @override
  Future<void> close() {
    AppLogger.info(
      'Closing NotificationsBloc and canceling stream subscriptions.',
    );
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _rtNotificationsSub?.cancel();
    _rtUnreadCountSub?.cancel();
    return super.close();
  }
}
