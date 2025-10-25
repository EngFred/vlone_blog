part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object> get props => [];
}

/// Event to start subscribing to the notifications stream.
/// This should be dispatched when the NotificationsPage is initialized.
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

/// Internal event used by the BLoC to handle new data from the notifications stream.
class _NotificationsStreamUpdated extends NotificationsEvent {
  final Either<Failure, List<NotificationEntity>> update;

  const _NotificationsStreamUpdated(this.update);

  @override
  List<Object> get props => [update];
}

/// Internal event used by the BLoC to handle new data from the unread count stream.
class _UnreadCountStreamUpdated extends NotificationsEvent {
  final Either<Failure, int> update;

  const _UnreadCountStreamUpdated(this.update);

  @override
  List<Object> get props => [update];
}
