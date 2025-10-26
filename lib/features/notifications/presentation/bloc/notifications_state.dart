// features/notifications/presentation/bloc/notifications_state.dart
part of 'notifications_bloc.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object> get props => [];
}

/// Initial state, before any subscription.
class NotificationsInitial extends NotificationsState {}

/// State while the initial subscription is being established.
class NotificationsLoading extends NotificationsState {}

/// State when notifications are successfully loaded or updated.
/// Now includes selection and deletion states.
class NotificationsLoaded extends NotificationsState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final bool isSelectionMode;
  final Set<String> selectedNotificationIds;
  final bool isDeleting; // To show a loading indicator during delete

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
    this.isSelectionMode = false,
    this.selectedNotificationIds = const {},
    this.isDeleting = false,
  });

  NotificationsLoaded copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    bool? isSelectionMode,
    Set<String>? selectedNotificationIds,
    bool? isDeleting,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedNotificationIds:
          selectedNotificationIds ?? this.selectedNotificationIds,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  List<Object> get props => [
    notifications,
    unreadCount,
    isSelectionMode,
    selectedNotificationIds,
    isDeleting,
  ];
}

/// State when an error occurs while fetching or streaming notifications.
class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object> get props => [message];
}
