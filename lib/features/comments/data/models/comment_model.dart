import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? parentCommentId;
  final String? username;
  final String? avatarUrl;
  final int? repliesCount;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
    this.username,
    this.avatarUrl,
    this.repliesCount,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    final dynamic createdAtRaw = map['created_at'];
    final DateTime createdAt = createdAtRaw is DateTime
        ? createdAtRaw.toUtc()
        : DateTime.parse(createdAtRaw.toString()).toUtc();

    // replies_count may be returned as int, string, or null depending on the driver
    int? parseRepliesCount(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return CommentModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      text: map['text'] as String,
      createdAt: createdAt,
      parentCommentId: map['parent_comment_id'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      repliesCount: parseRepliesCount(
        map['replies_count'] ?? map['repliesCount'],
      ),
    );
  }

  CommentEntity toEntity() {
    return CommentEntity(
      id: id,
      postId: postId,
      userId: userId,
      text: text,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      username: username,
      avatarUrl: avatarUrl,
      repliesCount: repliesCount,
    );
  }
}
