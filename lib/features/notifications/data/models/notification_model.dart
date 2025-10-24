class NotificationModel {
  final String id;
  final String recipientId;
  final String actorId;
  final String type; // 'like', 'comment', 'follow', etc.
  final String? postId;
  final String? content;
  final DateTime? readAt;
  final DateTime createdAt;

  // Fields from joined tables (assuming a view/RPC provides this)
  final String actorUsername;
  final String? actorImageUrl; // profile_image_url

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    this.postId,
    this.content,
    this.readAt,
    required this.createdAt,
    required this.actorUsername,
    this.actorImageUrl,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      recipientId: map['recipient_id'] as String,
      actorId: map['actor_id'] as String,
      type: map['type'] as String,
      postId: map['post_id'] as String?,
      content: map['content'] as String?,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      // Assuming these are joined fields from the 'actor' profile view
      actorUsername: map['actor_username'] as String,
      actorImageUrl: map['actor_image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type,
      'post_id': postId,
      'content': content,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'actor_username': actorUsername,
      'actor_image_url': actorImageUrl,
    };
  }

  // Helper to check if the notification has been read
  bool get isRead => readAt != null;
}
