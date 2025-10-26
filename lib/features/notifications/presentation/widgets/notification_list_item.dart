import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';

class NotificationListItem extends StatelessWidget {
  final NotificationEntity notification;
  final bool isSelectionMode;
  final bool isSelected;

  const NotificationListItem({
    super.key,
    required this.notification,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

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

  /// Handles notification tap
  void _onNotificationTapped(BuildContext context) {
    if (isSelectionMode) {
      // In selection mode, tap toggles selection
      context.read<NotificationsBloc>().add(
        NotificationsToggleSelection(notification.id),
      );
    } else {
      // In normal mode, tap marks as read
      if (!notification.isRead) {
        context.read<NotificationsBloc>().add(
          NotificationsMarkOneAsRead(notification.id),
        );
      }
      // NOTE navigation to related content is not implemented yet, that will come in later
    }
  }

  /// Handles notification long-press
  void _onNotificationLongPressed(BuildContext context) {
    if (!isSelectionMode) {
      // If not in selection mode, enter it and select this item
      context.read<NotificationsBloc>().add(
        NotificationsEnterSelectionMode(notification.id),
      );
    }
  }

  /// Handles single delete dialog
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<NotificationsBloc>().add(
                NotificationsDeleteOne(notification.id),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUnread = !notification.isRead;

    // Determine background color based on state
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.2);
    } else if (isUnread) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.05);
    } else {
      backgroundColor = theme.canvasColor;
    }

    return Material(
      color: backgroundColor, // Use dynamic background color
      child: InkWell(
        onTap: () => _onNotificationTapped(context),
        onLongPress: () => _onNotificationLongPressed(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show Checkbox or Avatar based on selection mode
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      _onNotificationTapped(context);
                    },
                  ),
                )
              else
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
              if (!isSelectionMode) const SizedBox(width: 12),

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

              // Show context-aware trailing widget
              if (isSelectionMode)
                // In selection mode, this space is occupied by the checkbox
                Container()
              else if (isUnread)
                // Unread Indicator
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                // Show a delete button for single-item deletion
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
                  onPressed: () => _showDeleteConfirmationDialog(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
