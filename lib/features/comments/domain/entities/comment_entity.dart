import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/extensions.dart';

class CommentEntity extends Equatable {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? parentCommentId;
  final String? username;
  final String? avatarUrl;
  final String? parentUsername;

  // NEW: server-provided quick replies count (may be null)
  final int? repliesCount;

  final List<CommentEntity> replies;

  const CommentEntity({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
    this.username,
    this.avatarUrl,
    this.parentUsername,
    this.repliesCount,
    this.replies = const [],
  });

  String get formattedCreatedAt => createdAt.formattedDateTime;

  CommentEntity copyWith({
    String? id,
    String? postId,
    String? userId,
    String? text,
    DateTime? createdAt,
    String? parentCommentId,
    String? username,
    String? avatarUrl,
    String? parentUsername,
    int? repliesCount,
    List<CommentEntity>? replies,
  }) {
    return CommentEntity(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      parentUsername: parentUsername ?? this.parentUsername,
      repliesCount: repliesCount ?? this.repliesCount,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    userId,
    text,
    createdAt,
    parentCommentId,
    username,
    avatarUrl,
    parentUsername,
    repliesCount,
    replies,
  ];
}
