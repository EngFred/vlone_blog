import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/delete_notifications_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/get_paginated_notifications_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_all_as_read_usecase.dart';
import 'package:vlone_blog_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final GetPaginatedNotificationsUseCase _getPaginatedNotificationsUseCase;
  final MarkAsReadUseCase _markAsReadUseCase;
  final MarkAllAsReadUseCase _markAllAsReadUseCase;
  final DeleteNotificationsUseCase _deleteNotificationsUseCase;
  // Subscriptions to the RealtimeService broadcast streams
  StreamSubscription<int>? _rtUnreadCountSub;
  // Pagination state
  static const int _pageSize = 20;
  bool _hasMore = true;
  DateTime? _lastCreatedAt;
  String? _lastId;
  // ADDED: Private variable to store the latest unread count from the stream
  int _latestUnreadCount = 0;
  // RealtimeService (injected)
  final RealtimeService realtimeService;

  NotificationsBloc({
    required GetPaginatedNotificationsUseCase getPaginatedNotificationsUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required MarkAllAsReadUseCase markAllAsReadUseCase,
    required DeleteNotificationsUseCase deleteNotificationsUseCase,
    required this.realtimeService,
  }) : _getPaginatedNotificationsUseCase = getPaginatedNotificationsUseCase,
       _markAsReadUseCase = markAsReadUseCase,
       _markAllAsReadUseCase = markAllAsReadUseCase,
       _deleteNotificationsUseCase = deleteNotificationsUseCase,
       super(NotificationsInitial()) {
    on<GetNotificationsEvent>(_onGetNotifications);
    on<LoadMoreNotificationsEvent>(_onLoadMoreNotifications);
    on<RefreshNotificationsEvent>(_onRefreshNotifications);
    on<NotificationsSubscribeUnreadCountStream>(_onSubscribeUnreadCountStream);
    on<_UnreadCountStreamUpdated>(_onUnreadCountUpdated);
    on<NotificationsMarkOneAsRead>(_onMarkOneAsRead);
    on<NotificationsMarkAllAsRead>(_onMarkAllAsRead);
    on<NotificationsDeleteOne>(_onDeleteOne);
    on<NotificationsDeleteSelected>(_onDeleteSelected);
    on<NotificationsEnterSelectionMode>(_onEnterSelectionMode);
    on<NotificationsExitSelectionMode>(_onExitSelectionMode);
    on<NotificationsToggleSelection>(_onToggleSelection);
  }

  Future<void> _onGetNotifications(
    GetNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    AppLogger.info('Loading initial notifications...');
    emit(const NotificationsLoading());
    final result = await _getPaginatedNotificationsUseCase(
      const GetPaginatedNotificationsParams(pageSize: _pageSize),
    );
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to load initial notifications: ${failure.message}',
        );
        emit(
          NotificationsError(
            ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (newNotifications) {
        _lastCreatedAt = newNotifications.isNotEmpty
            ? newNotifications.last.createdAt
            : null;
        _lastId = newNotifications.isNotEmpty ? newNotifications.last.id : null;
        _hasMore = newNotifications.length == _pageSize;
        AppLogger.info(
          'Loaded ${newNotifications.length} initial notifications, hasMore: $_hasMore',
        );
        emit(
          NotificationsLoaded(
            notifications: newNotifications,
            // CHANGED: Use the stored latest count
            unreadCount: _latestUnreadCount,
            hasMore: _hasMore,
          ),
        );
      },
    );
  }

  Future<void> _onLoadMoreNotifications(
    LoadMoreNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    if (!_hasMore || state is NotificationsLoadingMore) return;
    final currentState = state as NotificationsLoaded;
    emit(currentState.copyWith(isLoadingMore: true, loadMoreError: null));
    final result = await _getPaginatedNotificationsUseCase(
      GetPaginatedNotificationsParams(
        pageSize: _pageSize,
        lastCreatedAt: _lastCreatedAt,
        lastId: _lastId,
      ),
    );
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to load more notifications: ${failure.message}',
        );
        emit(
          currentState.copyWith(
            isLoadingMore: false,
            loadMoreError: ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (newNotifications) {
        final updatedNotifications = [
          ...currentState.notifications,
          ...newNotifications,
        ];
        _lastCreatedAt = newNotifications.isNotEmpty
            ? newNotifications.last.createdAt
            : null;
        _lastId = newNotifications.isNotEmpty ? newNotifications.last.id : null;
        _hasMore = newNotifications.length == _pageSize;
        AppLogger.info(
          'Loaded ${newNotifications.length} more notifications, hasMore: $_hasMore',
        );
        emit(
          NotificationsLoaded(
            notifications: updatedNotifications,
            unreadCount: currentState.unreadCount,
            hasMore: _hasMore,
            isLoadingMore: false,
          ),
        );
      },
    );
  }

  Future<void> _onRefreshNotifications(
    RefreshNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    _hasMore = true;
    _lastCreatedAt = null;
    _lastId = null;
    emit(const NotificationsLoading());
    final result = await _getPaginatedNotificationsUseCase(
      const GetPaginatedNotificationsParams(pageSize: _pageSize),
    );
    result.fold(
      (failure) {
        AppLogger.error('Failed to refresh notifications: ${failure.message}');
        emit(
          NotificationsError(
            ErrorMessageMapper.mapToUserMessage(failure.message),
          ),
        );
      },
      (newNotifications) {
        _lastCreatedAt = newNotifications.isNotEmpty
            ? newNotifications.last.createdAt
            : null;
        _lastId = newNotifications.isNotEmpty ? newNotifications.last.id : null;
        _hasMore = newNotifications.length == _pageSize;
        AppLogger.info(
          'Refreshed ${newNotifications.length} notifications, hasMore: $_hasMore',
        );
        emit(
          NotificationsLoaded(
            notifications: newNotifications,
            // CHANGED: Use the stored latest count
            unreadCount: _latestUnreadCount,
            hasMore: _hasMore,
          ),
        );
      },
    );
  }

  /// Handles subscribing to the unread count stream.
  void _onSubscribeUnreadCountStream(
    NotificationsSubscribeUnreadCountStream event,
    Emitter<NotificationsState> emit,
  ) {
    AppLogger.info('Subscribing to unread count stream...');
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
        // ADDED: Store the latest count
        _latestUnreadCount = count;
        AppLogger.info('Unread count stream updated: $count');
        final currentState = state;
        if (currentState is NotificationsLoaded) {
          emit(currentState.copyWith(unreadCount: count));
        } else {
          // Added: Handle non-Loaded states by emitting initial Loaded with unread count
          emit(
            NotificationsLoaded(
              notifications: const [],
              unreadCount: count,
              hasMore: _hasMore,
            ),
          );
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
      orElse: () => throw Exception('Notification not found'),
    );
    if (item.isRead) return;
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
    // Optimistic update of local stored count
    _latestUnreadCount = newUnreadCount;

    final result = await _markAsReadUseCase(event.notificationId);
    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to mark notification ${event.notificationId} as read: ${failure.message}',
        );
        // Revert optimistic update if needed
        emit(currentState);
        _latestUnreadCount = currentState.unreadCount;
      },
      (_) => AppLogger.info(
        'Notification ${event.notificationId} marked as read via API.',
      ),
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
    // Optimistic update of local stored count
    _latestUnreadCount = 0;

    final result = await _markAllAsReadUseCase(NoParams());
    result.fold((failure) {
      AppLogger.error('Failed to mark all as read: ${failure.message}');
      // Revert
      emit(currentState);
      _latestUnreadCount = currentState.unreadCount;
    }, (_) => AppLogger.info('All notifications marked as read via API.'));
  }

  /// Handles deleting a single notification.
  Future<void> _onDeleteOne(
    NotificationsDeleteOne event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;
    final currentState = state as NotificationsLoaded;
    final deletedItem = currentState.notifications.firstWhere(
      (n) => n.id == event.notificationId,
    );
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
        if (!deletedItem.isRead) {
          newUnreadCount = (currentState.unreadCount - 1).clamp(0, 9999);
        }
        // Update local stored count
        _latestUnreadCount = newUnreadCount;

        emit(
          NotificationsLoaded(
            notifications: updatedList,
            unreadCount: newUnreadCount,
            hasMore: currentState.hasMore,
            selectedNotificationIds: newSelectedIds,
            isSelectionMode: newSelectedIds.isNotEmpty,
            isDeleting: false,
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

        // Update local stored count
        _latestUnreadCount = newUnreadCount;

        emit(
          NotificationsLoaded(
            notifications: updatedList,
            unreadCount: newUnreadCount,
            hasMore: currentState.hasMore,
            isSelectionMode: false,
            selectedNotificationIds: <String>{},
            isDeleting: false,
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
        selectedNotificationIds: <String>{},
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
    if (newIds.contains(event.notificationId)) {
      newIds.remove(event.notificationId);
    } else {
      newIds.add(event.notificationId);
    }
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
    _rtUnreadCountSub?.cancel();
    return super.close();
  }
}
