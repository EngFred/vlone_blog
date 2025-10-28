import 'package:equatable/equatable.dart';

/// Enum to represent the different types of notifications.
enum NotificationType {
  like,
  comment,
  follow,
  repost,
  mention,
  favorite,
  unknown;

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

  // Optional: related post & comment
  final String? postId;
  final String? commentId; // NEW
  final String? parentCommentId; // NEW

  // Optional: custom content / friendly message
  final String? content;

  // Optional: arbitrary metadata from DB (e.g., {"reply_text": "...", "deep_link": "..."})
  final Map<String, dynamic>? metadata; // NEW

  const NotificationEntity({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    this.parentCommentId,
    this.content,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  /// Creates a new instance of [NotificationEntity] with updated fields.
  NotificationEntity copyWith({
    String? id,
    String? recipientId,
    NotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    String? actorId,
    String? actorUsername,
    String? actorAvatarUrl,
    String? postId,
    String? commentId,
    String? parentCommentId,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actorId: actorId ?? this.actorId,
      actorUsername: actorUsername ?? this.actorUsername,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }

  /// A constant empty notification entity.
  static final NotificationEntity empty = NotificationEntity(
    id: '',
    recipientId: '',
    actorId: '',
    type: NotificationType.unknown,
    actorUsername: '',
    isRead: true,
    createdAt: DateTime.fromMicrosecondsSinceEpoch(0),
  );

  @override
  List<Object?> get props => [
    id,
    recipientId,
    actorId,
    type,
    postId,
    commentId,
    parentCommentId,
    isRead,
    createdAt,
    actorUsername,
    actorAvatarUrl,
    content,
    metadata,
  ];
}
