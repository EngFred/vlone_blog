import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
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

  StreamSubscription<Either<Failure, List<NotificationEntity>>>?
  _notificationsSubscription;

  StreamSubscription<Either<Failure, int>>? _unreadCountSubscription;

  NotificationsBloc({
    required GetNotificationsStreamUseCase getNotificationsStreamUseCase,
    required GetUnreadCountStreamUseCase getUnreadCountStreamUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required MarkAllAsReadUseCase markAllAsReadUseCase,
    required DeleteNotificationsUseCase deleteNotificationsUseCase,
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

  /// Handles the initial subscription event for the notifications list.
  void _onSubscribeStream(
    NotificationsSubscribeStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info('Subscribing to notifications stream...');
    if (state is NotificationsInitial) {
      emit(NotificationsLoading());
    }

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
      (update) => add(_UnreadCountStreamUpdated(update)),
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
        // This `notifications` is List<NotificationModel> at runtime
        AppLogger.info(
          'Notifications stream updated with ${notifications.length} items.',
        );

        // --- FIX ---
        // Create a new list with the runtime type List<NotificationEntity>
        // to avoid runtime type errors with `firstWhere`'s `orElse`.
        final List<NotificationEntity> entityList = List.from(notifications);
        // --- END FIX ---

        if (state is NotificationsLoaded) {
          final currentState = state as NotificationsLoaded;
          emit(
            currentState.copyWith(
              notifications: entityList, // Use the new list
              // Prune any selected IDs that no longer exist
              selectedNotificationIds: currentState.selectedNotificationIds
                  .where((id) => entityList.any((n) => n.id == id))
                  .toSet(),
            ),
          );
        } else {
          // Otherwise, emit a fresh loaded state
          emit(
            NotificationsLoaded(
              notifications: entityList, // Use the new list
              unreadCount: 0, // Will be updated by its own stream
            ),
          );
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
          // We got a count update, but not a notification list yet
          emit(
            NotificationsLoaded(
              notifications: [], // Start with empty list
              unreadCount: count,
            ),
          );
        }
      },
    );
  }

  /// Handles marking a single notification as read.
  void _onMarkOneAsRead(
    NotificationsMarkOneAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking notification ${event.notificationId} as read.');

    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    // Find the item to see if it was *actually* unread
    // This call is now safe because `currentState.notifications`
    // is a `List<NotificationEntity>` at runtime.
    final item = currentState.notifications.firstWhere(
      (n) => n.id == event.notificationId,
      orElse: () => NotificationEntity.empty, // Handle case if not found
    );

    // If it's already read (or not found), do nothing
    if (item.id.isEmpty || item.isRead) {
      final result = await _markAsReadUseCase(
        event.notificationId,
      ); // Still call API to be sure
      result.fold(
        (failure) => AppLogger.error(
          'Failed to mark (already read) notification: ${failure.message}',
        ),
        (_) => AppLogger.info('Notification marked as read via API.'),
      );
      return;
    }

    // Create a new list with the updated item
    final updatedList = currentState.notifications.map((n) {
      if (n.id == event.notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final newUnreadCount = (currentState.unreadCount - 1).clamp(0, 9999);

    // Emit the new state optimistically
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
        // Rollback on failure
        emit(currentState);
      },
      (_) {
        AppLogger.info(
          'Notification ${event.notificationId} marked as read via API.',
        );
        // On success, our optimistic state is correct.
      },
    );
  }

  /// Handles marking all notifications as read.
  void _onMarkAllAsRead(
    NotificationsMarkAllAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Marking all notifications as read.');

    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    if (currentState.unreadCount == 0) return; // Nothing to do

    // Create a new list with all items marked as read
    final updatedList = currentState.notifications.map((n) {
      if (n.isRead) return n; // No change
      return n.copyWith(isRead: true);
    }).toList();

    // Emit the new state optimistically
    emit(
      currentState.copyWith(
        notifications: updatedList,
        unreadCount: 0, // We know this will be 0
      ),
    );

    final result = await _markAllAsReadUseCase(NoParams());

    result.fold(
      (failure) {
        AppLogger.error('Failed to mark all as read: ${failure.message}');
        // Rollback on failure
        emit(currentState);
      },
      (_) {
        AppLogger.info('All notifications marked as read via API.');
        // Success!
      },
    );
  }

  /// Handles deleting a single notification.
  Future<void> _onDeleteOne(
    NotificationsDeleteOne event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    // Find the item *before* deleting to check if it was unread
    final NotificationEntity deletedItem;
    try {
      deletedItem = currentState.notifications.firstWhere(
        (n) => n.id == event.notificationId,
      );
    } catch (e) {
      AppLogger.error(
        'Item ${event.notificationId} not found in state for deletion.',
      );
      return; // Item doesn't exist in local state, nothing to do
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
        // On failure, just stop loading
        emit(currentState.copyWith(isDeleting: false));
      },
      (_) {
        AppLogger.info('Notification ${event.notificationId} deleted via API.');

        // Create a new list without the deleted item
        final updatedList = currentState.notifications
            .where((n) => n.id != event.notificationId)
            .toList();

        // Also update selection state
        final newSelectedIds = Set<String>.from(
          currentState.selectedNotificationIds,
        )..remove(event.notificationId);

        // Check if the deleted item was unread to update count
        int newUnreadCount = currentState.unreadCount;
        if (deletedItem.isRead == false) {
          newUnreadCount = (currentState.unreadCount - 1).clamp(0, 9999);
        }

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

  /// Handles deleting all selected notifications.
  Future<void> _onDeleteSelected(
    NotificationsDeleteSelected event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    final idsToDelete = currentState.selectedNotificationIds; // This is a Set

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
        // On failure, just stop loading
        emit(currentState.copyWith(isDeleting: false));
      },
      (_) {
        AppLogger.info('${idsToDelete.length} notifications deleted via API.');

        // Create a new list without the deleted items
        final updatedList = currentState.notifications
            .where((n) => !idsToDelete.contains(n.id))
            .toList();

        // Count how many unread items were deleted
        int unreadDeletedCount = 0;
        for (final n in currentState.notifications) {
          if (idsToDelete.contains(n.id) && !n.isRead) {
            unreadDeletedCount++;
          }
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

  /// Handles entering selection mode.
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

  /// Handles exiting selection mode.
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

  /// Handles toggling a single item's selection state.
  void _onToggleSelection(
    NotificationsToggleSelection event,
    Emitter<NotificationsState> emit,
  ) {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;

    final currentIds = currentState.selectedNotificationIds;
    final newIds = Set<String>.from(currentIds);

    if (newIds.contains(event.notificationId)) {
      newIds.remove(event.notificationId);
    } else {
      newIds.add(event.notificationId);
    }

    emit(
      currentState.copyWith(
        selectedNotificationIds: newIds,
        // If user deselects the last item, exit selection mode
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
    return super.close();
  }
}
