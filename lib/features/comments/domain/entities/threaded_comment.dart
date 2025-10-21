import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class ThreadedComment {
  final CommentEntity comment;
  final int depth;

  const ThreadedComment({required this.comment, required this.depth});
}
