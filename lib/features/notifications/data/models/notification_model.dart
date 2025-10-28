import 'dart:convert';

import 'package:vlone_blog_app/features/notifications/domain/entities/notification_entity.dart';

/// Extends [NotificationEntity] to include data-layer specific logic,
/// like [fromMap] and [toMap] converters.
class NotificationModel extends NotificationEntity {
  /// The [readAt] field from the database.
  final DateTime? readAt;

  const NotificationModel({
    required super.id,
    required super.recipientId,
    required super.actorId,
    required super.type,
    required super.createdAt,
    required super.actorUsername,
    super.actorAvatarUrl,
    super.postId,
    super.content,
    this.readAt,
    super.commentId,
    super.parentCommentId,
    super.metadata,
  }) : super(isRead: readAt != null);

  /// Creates a [NotificationModel] from a Supabase database map (JSON).
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    // parse metadata robustly (could be stringified JSON or map)
    Map<String, dynamic>? metadata;
    try {
      final rawMeta = map['metadata'];
      if (rawMeta == null) {
        metadata = null;
      } else if (rawMeta is Map) {
        metadata = Map<String, dynamic>.from(rawMeta);
      } else if (rawMeta is String) {
        // sometimes postgres returns jsonb as string
        metadata = rawMeta.isEmpty
            ? null
            : Map<String, dynamic>.from(
                (rawMeta.startsWith('{') || rawMeta.startsWith('['))
                    ? (jsonDecode(rawMeta) as Map<String, dynamic>)
                    : {},
              );
      } else {
        metadata = null;
      }
    } catch (_) {
      metadata = null;
    }

    return NotificationModel(
      id: map['id'] as String,
      recipientId: map['recipient_id'] as String,
      actorId: map['actor_id'] as String,
      type: NotificationType.fromString(map['type'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      parentCommentId: map['parent_comment_id'] as String?,
      content: map['content'] as String?,
      actorUsername: map['actor_username'] as String? ?? 'Unknown',
      actorAvatarUrl: map['actor_image_url'] as String?,
      metadata: metadata,
    );
  }

  /// Converts the [NotificationModel] to a Map (JSON).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type.name,
      'post_id': postId,
      'comment_id': commentId,
      'parent_comment_id': parentCommentId,
      'content': content,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'actor_username': actorUsername,
      'actor_image_url': actorAvatarUrl,
      'metadata': metadata,
    };
  }
}
