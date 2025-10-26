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
  }) : super(
         // The entity's `isRead` is derived from the model's `readAt`
         isRead: readAt != null,
       );

  /// Creates a [NotificationModel] from a Supabase database map (JSON).
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
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
      content: map['content'] as String?,

      // These fields are expected from the 'notifications_view'
      // which should join with the 'profiles' table.
      actorUsername: map['actor_username'] as String? ?? 'Unknown User',
      // Changed to match the SQL view's column name
      actorAvatarUrl: map['actor_image_url'] as String?,
    );
  }

  /// Converts the [NotificationModel] to a Map (JSON).
  /// Not strictly necessary for this feature but good practice.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type.name,
      'post_id': postId,
      'content': content,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      // These are not part of the 'notifications' table,
      // but are included for completeness if ever needed.
      'actor_username': actorUsername,
      'actor_image_url': actorAvatarUrl,
    };
  }
}
