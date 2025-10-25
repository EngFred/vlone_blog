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
class NotificationsLoaded extends NotificationsState {
  final List<NotificationEntity> notifications;
  final int unreadCount;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  List<Object> get props => [notifications, unreadCount];
}

/// State when an error occurs while fetching or streaming notifications.
class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object> get props => [message];
}
