import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/extensions.dart';

class CommentEntity extends Equatable {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? parentCommentId;

  const CommentEntity({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
  });

  String get formattedCreatedAt => createdAt.formattedDateTime;

  @override
  List<Object?> get props => [
    id,
    postId,
    userId,
    text,
    createdAt,
    parentCommentId,
  ];
}
