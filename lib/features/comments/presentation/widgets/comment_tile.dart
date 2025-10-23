import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class CommentTile extends StatefulWidget {
  final CommentEntity comment;
  final void Function(CommentEntity) onReply;
  final int depth;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    this.depth = 0,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isRepliesExpanded = false;

  List<CommentEntity> _flattenReplies(List<CommentEntity> replies) {
    final List<CommentEntity> flatList = [];

    void _addRecursively(CommentEntity comment) {
      flatList.add(comment);
      for (final reply in comment.replies) {
        _addRecursively(reply);
      }
    }

    for (final reply in replies) {
      _addRecursively(reply);
    }
    return flatList;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final hasReplies = comment.replies.isNotEmpty;
    final replyCount = comment.replies.length;
    final replyText = replyCount == 1 ? 'reply' : 'replies';

    const avatarRadius = 20.0;

    final horizontalPadding = widget.depth == 0 ? 16.0 : 40.0;

    final flatReplies = _flattenReplies(comment.replies);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 8.0, 16.0, 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: avatarRadius,
                backgroundImage: comment.avatarUrl != null
                    ? CachedNetworkImageProvider(comment.avatarUrl!)
                    : null,
                child: comment.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 10),

              // Comment Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row (Username and Time)
                    Row(
                      children: [
                        Text(
                          comment.username ?? 'Anonymous',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${timeago.format(comment.createdAt, locale: 'en_short')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Textual Reply Context (Replying to @parentUser)
                    if (comment.parentUsername != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text.rich(
                          TextSpan(
                            text: 'Replying to ',
                            style: theme.textTheme.bodySmall,
                            children: [
                              TextSpan(
                                text: '@${comment.parentUsername}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Comment Text
                    Text(comment.text, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),

                    // Actions Row
                    Row(
                      children: [
                        // Reply button
                        GestureDetector(
                          onTap: () => widget.onReply(comment),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Text(
                              'Reply',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),

                        // "View Replies" button
                        if (hasReplies && widget.depth < 1)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRepliesExpanded = !_isRepliesExpanded;
                              });
                            },
                            child: Text(
                              // ✅ FIX: Use dynamic replyText for pluralization
                              _isRepliesExpanded
                                  ? 'Hide $replyCount $replyText'
                                  : 'View $replyCount $replyText',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Optional Separator for root comments
        if (widget.depth == 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 1, indent: 50),
          ),

        // Expanded Replies Section (Hybrid)
        if (hasReplies && widget.depth < 1)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !_isRepliesExpanded
                ? const SizedBox.shrink()
                : Column(
                    children: flatReplies.map((reply) {
                      // All replies inside the expansion are rendered with depth 1.
                      return CommentTile(
                        key: ValueKey(reply.id),
                        comment: reply,
                        onReply: widget.onReply,
                        depth: 1, // Enforce single indent
                      );
                    }).toList(),
                  ),
          ),
      ],
    );
  }
}
