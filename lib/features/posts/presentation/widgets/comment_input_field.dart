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
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // UI/UX: Enhanced Replying-To Banner
        if (replyingTo != null)
          Container(
            // Use primary color for strong visual context
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
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
                  tooltip: 'Cancel reply',
                  splashRadius: 20,
                ),
              ],
            ),
          ),

        // Input Area Container with subtle shadow
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18, // Slightly smaller for better proportion
                    backgroundImage: post.avatarUrl != null
                        ? NetworkImage(post.avatarUrl!)
                        : null,
                    child: post.avatarUrl == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction:
                          TextInputAction.send, // Send on keyboard done
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
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ), // Subtle background fill
                        // UI/UX: Pill-shaped border and integrated send button
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
                          icon: Icon(
                            Icons.send_rounded,
                            color: controller.text.isNotEmpty
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          onPressed: onSend,
                          splashRadius: 20,
                        ),
                      ),
                    ),
                  ),
                  // Removed the external IconButton as it's now in the suffixIcon
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
