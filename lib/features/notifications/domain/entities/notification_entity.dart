import 'package:equatable/equatable.dart';

/// Enum to represent the different types of notifications.
enum NotificationType {
  like,
  comment,
  follow,
  repost,
  mention,
  favorite,
  unknown; // Fallback for any unexpected types

  static NotificationType fromString(String? type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'repost':
        return NotificationType.repost;
      case 'mention':
        return NotificationType.mention;
      case 'favorite':
        return NotificationType.favorite;
      default:
        return NotificationType.unknown;
    }
  }
}

/// Represents the core Notification business object.
class NotificationEntity extends Equatable {
  final String id;
  final String recipientId;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  // Actor (the user who performed the action)
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;

  // Optional: related post
  final String? postId;

  // Optional: custom content (e.g., for a mention)
  final String? content;

  const NotificationEntity({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.postId,
    this.content,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    recipientId,
    actorId,
    type,
    postId,
    isRead,
    createdAt,
    actorUsername,
    actorAvatarUrl,
  ];
}
