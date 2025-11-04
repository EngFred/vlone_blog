import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class CommentInputField extends StatelessWidget {
  final String? userAvatarUrl;
  final TextEditingController controller;
  final FocusNode focusNode;
  final CommentEntity? replyingTo;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  const CommentInputField({
    super.key,
    required this.userAvatarUrl,
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.onSend,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null)
            Container(
              color: theme.colorScheme.primaryContainer.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @${replyingTo!.username ?? 'user'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onCancelReply,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: userAvatarUrl != null
                      ? NetworkImage(userAvatarUrl!)
                      : null,
                  child: userAvatarUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: replyingTo == null
                          ? 'Add a comment...'
                          : 'Reply...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send_rounded),
                        onPressed: onSend,
                        splashRadius: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
