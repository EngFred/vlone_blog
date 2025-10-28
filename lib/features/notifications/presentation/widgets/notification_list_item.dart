import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
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
  String _getNotificationMessage(NotificationType type, BuildContext context) {
    // Check for comment-related notifications first, as they have more complexity.
    if (type == NotificationType.comment) {
      // Check if this is a reply notification (parentCommentId is not null)
      if (notification.parentCommentId != null &&
          notification.parentCommentId!.isNotEmpty) {
        // --- ADVANCED REPLY MESSAGE LOGIC ---

        // 1. Get the current user ID from the AuthBloc
        final currentUserId = context.read<AuthBloc>().cachedUser?.id;

        // 2. Get the post owner ID from notification metadata
        final String? postOwnerId =
            notification.metadata?['post_owner_id'] as String?;

        // 3. Determine if the current user is the post owner
        final bool isPostOwner =
            currentUserId != null && postOwnerId == currentUserId;

        if (isPostOwner) {
          // e.g., Alice replied to your comment on YOUR post.
          return 'replied to your comment on your post.';
        } else {
          // e.g., Alice replied to your comment on Fred's post.
          return 'replied to your comment on a post.';
        }
      } else {
        // This is a comment on the current user's post.
        return 'commented on your post.';
      }
    }

    // Handle other types of notifications
    switch (type) {
      case NotificationType.like:
        return 'liked your post.';
      case NotificationType.follow:
        return 'started following you.';
      case NotificationType.repost:
        return 'reposted your post.';
      case NotificationType.mention:
        return 'mentioned you in a post.';
      case NotificationType.favorite:
        return 'favorited your post.';
      case NotificationType.unknown:
      case NotificationType.comment: // Already handled above
        return 'sent you a notification.';
    }
  }

  /// Handles navigation for the given notification.
  void _navigateForNotification(BuildContext context) {
    // guard
    final router = GoRouter.of(context);

    switch (notification.type) {
      case NotificationType.follow:
        // go to the actor's profile
        router.push('${Constants.profileRoute}/${notification.actorId}');
        break;
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.favorite:
      case NotificationType.repost:
      case NotificationType.mention:
        // Navigate to post details; pass commentId if available so PostDetailsPage can highlight/scroll to it.
        if (notification.postId != null && notification.postId!.isNotEmpty) {
          router.push(
            '${Constants.postDetailsRoute}/${notification.postId}',
            extra: {
              'highlightCommentId': notification.commentId,
              'parentCommentId': notification.parentCommentId,
              // optionally pass metadata for deeper navigation handling
              'notification_metadata': notification.metadata,
            },
          );
        } else {
          // Fallback: if no post id (rare), navigate to actor profile
          router.push('${Constants.profileRoute}/${notification.actorId}');
        }
        break;
      case NotificationType.unknown:
        // Default behavior: open actor profile
        router.push('${Constants.profileRoute}/${notification.actorId}');
        break;
    }
  }

  /// Handles notification tap
  void _onNotificationTapped(BuildContext context) {
    if (isSelectionMode) {
      context.read<NotificationsBloc>().add(
        NotificationsToggleSelection(notification.id),
      );
      return;
    }

    // mark as read if unread
    if (!notification.isRead) {
      context.read<NotificationsBloc>().add(
        NotificationsMarkOneAsRead(notification.id),
      );
    }

    // navigate to related item
    try {
      _navigateForNotification(context);
    } catch (e) {
      // swallow navigation errors (log via app logger if desired)
    }
  }

  /// Handles notification long-press
  void _onNotificationLongPressed(BuildContext context) {
    if (!isSelectionMode) {
      context.read<NotificationsBloc>().add(
        NotificationsEnterSelectionMode(notification.id),
      );
    }
  }

  /// Single delete dialog
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

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.2);
    } else if (isUnread) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.05);
    } else {
      backgroundColor = theme.canvasColor;
    }

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () => _onNotificationTapped(context),
        onLongPress: () => _onNotificationLongPressed(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _onNotificationTapped(context),
                  ),
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundImage: notification.actorAvatarUrl != null
                      ? NetworkImage(notification.actorAvatarUrl!)
                      : null,
                  child:
                      notification.actorAvatarUrl == null &&
                          notification.actorUsername.isNotEmpty
                      ? Text(notification.actorUsername[0].toUpperCase())
                      : null,
                ),
              if (!isSelectionMode) const SizedBox(width: 12),
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
                                ' ${_getNotificationMessage(notification.type, context)}', // <--- context passed here
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
              if (isSelectionMode)
                Container()
              else if (isUnread)
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
