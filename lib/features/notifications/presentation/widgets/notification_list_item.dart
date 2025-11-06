import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/presentation/widgets/cutsom_alert_dialog.dart';
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

  String _getNotificationMessage(NotificationType type, BuildContext context) {
    if (type == NotificationType.comment) {
      if (notification.parentCommentId != null &&
          notification.parentCommentId!.isNotEmpty) {
        final currentUserId = context.read<AuthBloc>().cachedUser?.id;
        final String? postOwnerId =
            notification.metadata?['post_owner_id'] as String?;
        final bool isPostOwner =
            currentUserId != null && postOwnerId == currentUserId;

        if (isPostOwner) {
          return 'replied to your comment on your post.';
        } else {
          return 'replied to your comment on a post.';
        }
      } else {
        return 'commented on your post.';
      }
    }

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
      case NotificationType.comment:
        return 'sent you a notification.';
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.comment_rounded;
      case NotificationType.follow:
        return Icons.person_add_rounded;
      case NotificationType.repost:
        return Icons.repeat_rounded;
      case NotificationType.mention:
        return Icons.alternate_email_rounded;
      case NotificationType.favorite:
        return Icons.bookmark_rounded;
      case NotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(NotificationType type, BuildContext context) {
    final theme = Theme.of(context);
    switch (type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.follow:
        return Colors.green;
      case NotificationType.repost:
        return Colors.purple;
      case NotificationType.mention:
        return Colors.orange;
      case NotificationType.favorite:
        return Colors.amber;
      case NotificationType.unknown:
        return theme.colorScheme.primary;
    }
  }

  void _onNotificationTapped(BuildContext context) {
    if (isSelectionMode) {
      context.read<NotificationsBloc>().add(
        NotificationsToggleSelection(notification.id),
      );
      return;
    }

    if (!notification.isRead) {
      context.read<NotificationsBloc>().add(
        NotificationsMarkOneAsRead(notification.id),
      );
    }

    try {
      _navigateForNotification(context);
    } catch (e) {
      // Handle navigation errors silently
    }
  }

  void _navigateForNotification(BuildContext context) {
    final router = GoRouter.of(context);

    switch (notification.type) {
      case NotificationType.follow:
        router.push('${Constants.profileRoute}/${notification.actorId}');
        break;
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.favorite:
      case NotificationType.repost:
      case NotificationType.mention:
        if (notification.postId != null && notification.postId!.isNotEmpty) {
          router.push(
            '${Constants.postDetailsRoute}/${notification.postId}',
            extra: {
              'highlightCommentId': notification.commentId,
              'parentCommentId': notification.parentCommentId,
              'notification_metadata': notification.metadata,
            },
          );
        } else {
          router.push('${Constants.profileRoute}/${notification.actorId}');
        }
        break;
      case NotificationType.unknown:
        router.push('${Constants.profileRoute}/${notification.actorId}');
        break;
    }
  }

  void _onNotificationLongPressed(BuildContext context) {
    if (!isSelectionMode) {
      context.read<NotificationsBloc>().add(
        NotificationsEnterSelectionMode(notification.id),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showCustomDialog<bool>(
      context: context,
      title: 'Delete Notification?',
      content: const Text('This action cannot be undone.'),
      actions: [
        DialogActions.createCancelButton(context, label: 'Cancel'),
        DialogActions.createPrimaryButton(
          context,
          label: 'Delete',
          onPressed: () {
            context.read<NotificationsBloc>().add(
              NotificationsDeleteOne(notification.id),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isUnread = !notification.isRead;
    final notificationColor = _getNotificationColor(notification.type, context);

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
    } else if (isUnread) {
      backgroundColor = notificationColor.withOpacity(0.05);
    } else {
      backgroundColor = theme.colorScheme.surface;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onNotificationTapped(context),
          onLongPress: () => _onNotificationLongPressed(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0, top: 2.0),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _onNotificationTapped(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          notificationColor.withOpacity(0.2),
                          notificationColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.surface,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: notification.actorAvatarUrl != null
                                ? NetworkImage(notification.actorAvatarUrl!)
                                : null,
                            child:
                                notification.actorAvatarUrl == null &&
                                    notification.actorUsername.isNotEmpty
                                ? Text(
                                    notification.actorUsername[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              size: 12,
                              color: notificationColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!isSelectionMode) const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: notification.actorUsername,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${_getNotificationMessage(notification.type, context)}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeago.format(notification.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: notificationColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      size: 20,
                    ),
                    onPressed: () => _showDeleteConfirmationDialog(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
