import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';

class NotificationListItem extends StatelessWidget {
  final NotificationEntity notification;

  const NotificationListItem({super.key, required this.notification});

  /// Helper to generate the notification message
  String _getNotificationMessage(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'liked your post.';
      case NotificationType.comment:
        return 'commented on your post.';
      case NotificationType.follow:
        return 'started following you.';
      case NotificationType.repost:
        return 'reposted your post.';
      case NotificationType.mention:
        return 'mentioned you in a post.';
      case NotificationType.favorite:
        return 'favorited your post.';
      case NotificationType.unknown:
        return 'sent you a notification.';
    }
  }

  /// Handles notification tap - marks as read without navigation
  void _onNotificationTapped(BuildContext context) {
    // Mark the notification as read - user stays on notifications page
    if (!notification.isRead) {
      context.read<NotificationsBloc>().add(
        NotificationsMarkOneAsRead(notification.id),
      );
    }

    // Navigation logic commented out - user stays on notifications page
    //
    /*
    switch (notification.type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.repost:
      case NotificationType.mention:
      case NotificationType.favorite:
        if (notification.postId != null) {
          context.go('${Constants.postDetailsRoute}/${notification.postId}');
        }
        break;
      case NotificationType.follow:
        context.go('${Constants.profileRoute}/${notification.actorId}');
        break;
      case NotificationType.unknown:
        break;
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUnread = !notification.isRead;

    return Material(
      color: isUnread
          ? theme.colorScheme.primary.withOpacity(0.05)
          : theme.canvasColor,
      child: InkWell(
        onTap: () => _onNotificationTapped(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actor's Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: notification.actorAvatarUrl != null
                    ? NetworkImage(notification.actorAvatarUrl!)
                    : null,
                child: notification.actorAvatarUrl == null
                    ? Text(notification.actorUsername[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              // Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: notification.actorUsername,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                ' ${_getNotificationMessage(notification.type)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Unread Indicator
              if (isUnread)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
