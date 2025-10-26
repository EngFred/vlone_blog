part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object> get props => [];
}

/// Event to start subscribing to the notifications stream.
class NotificationsSubscribeStream extends NotificationsEvent {}

/// Event to start subscribing to the unread count stream.
class NotificationsSubscribeUnreadCountStream extends NotificationsEvent {}

/// Event to mark a single notification as read.
class NotificationsMarkOneAsRead extends NotificationsEvent {
  final String notificationId;

  const NotificationsMarkOneAsRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

/// Event to mark all unread notifications as read.
class NotificationsMarkAllAsRead extends NotificationsEvent {}

/// Event to delete a single notification (e.g., from a long-press dialog).
class NotificationsDeleteOne extends NotificationsEvent {
  final String notificationId;

  const NotificationsDeleteOne(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

/// Event to delete all currently selected notifications.
class NotificationsDeleteSelected extends NotificationsEvent {}

/// Event to enter selection mode (e.g., on long-press).
class NotificationsEnterSelectionMode extends NotificationsEvent {
  final String firstNotificationId;

  const NotificationsEnterSelectionMode(this.firstNotificationId);

  @override
  List<Object> get props => [firstNotificationId];
}

/// Event to exit selection mode (e.g., on cancel button press).
class NotificationsExitSelectionMode extends NotificationsEvent {}

/// Event to toggle the selection state of a single notification.
class NotificationsToggleSelection extends NotificationsEvent {
  final String notificationId;

  const NotificationsToggleSelection(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

/// Internal event for new data from the notifications stream.
class _NotificationsStreamUpdated extends NotificationsEvent {
  final Either<Failure, List<NotificationEntity>> update;

  const _NotificationsStreamUpdated(this.update);

  @override
  List<Object> get props => [update];
}

/// Internal event for new data from the unread count stream.
class _UnreadCountStreamUpdated extends NotificationsEvent {
  final Either<Failure, int> update;

  const _UnreadCountStreamUpdated(this.update);

  @override
  List<Object> get props => [update];
}
