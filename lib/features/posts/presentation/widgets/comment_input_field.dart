import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class CommentInputField extends StatelessWidget {
  final PostEntity post;
  final TextEditingController controller;
  final FocusNode focusNode;
  final CommentEntity? replyingTo;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  const CommentInputField({
    super.key,
    required this.post,
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.onSend,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyingTo != null)
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Replying to @${replyingTo!.username ?? 'user'}'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancelReply,
                ),
              ],
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.avatarUrl != null
                      ? NetworkImage(post.avatarUrl!)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: replyingTo == null
                          ? 'Add a comment...'
                          : 'Reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: onSend),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
