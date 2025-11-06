part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object> get props => [];
}

class GetNotificationsEvent extends NotificationsEvent {
  const GetNotificationsEvent();
}

class LoadMoreNotificationsEvent extends NotificationsEvent {
  const LoadMoreNotificationsEvent();
}

class RefreshNotificationsEvent extends NotificationsEvent {
  const RefreshNotificationsEvent();
}

class NotificationsSubscribeUnreadCountStream extends NotificationsEvent {
  const NotificationsSubscribeUnreadCountStream();
}

class NotificationsMarkOneAsRead extends NotificationsEvent {
  final String notificationId;

  const NotificationsMarkOneAsRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class NotificationsMarkAllAsRead extends NotificationsEvent {
  const NotificationsMarkAllAsRead();
}

class NotificationsDeleteOne extends NotificationsEvent {
  final String notificationId;

  const NotificationsDeleteOne(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class NotificationsDeleteSelected extends NotificationsEvent {
  const NotificationsDeleteSelected();
}

class NotificationsEnterSelectionMode extends NotificationsEvent {
  final String firstNotificationId;

  const NotificationsEnterSelectionMode(this.firstNotificationId);

  @override
  List<Object> get props => [firstNotificationId];
}

class NotificationsExitSelectionMode extends NotificationsEvent {
  const NotificationsExitSelectionMode();
}

class NotificationsToggleSelection extends NotificationsEvent {
  final String notificationId;

  const NotificationsToggleSelection(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class _UnreadCountStreamUpdated extends NotificationsEvent {
  final Either<Failure, int> update;

  const _UnreadCountStreamUpdated(this.update);

  @override
  List<Object> get props => [update];
}
