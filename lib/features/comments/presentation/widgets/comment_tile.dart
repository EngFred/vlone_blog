import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

class CommentTile extends StatefulWidget {
  final CommentEntity comment;
  final void Function(CommentEntity) onReply;
  final int depth;
  final String currentUserId;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    this.depth = 0,
    required this.currentUserId,
  });

  @override
  State<CommentTile> createState() => CommentTileState();
}

class CommentTileState extends State<CommentTile> {
  bool _isRepliesExpanded = false;

  void _navigateToProfile(BuildContext context) {
    if (widget.comment.userId == widget.currentUserId) {
      context.go('${Constants.profileRoute}/me');
    } else {
      context.push('${Constants.profileRoute}/${widget.comment.userId}');
    }
  }

  List<CommentEntity> _flattenReplies(List<CommentEntity> replies) {
    final List<CommentEntity> flatList = [];
    void addRecursively(CommentEntity comment) {
      flatList.add(comment);
      for (final reply in comment.replies) {
        addRecursively(reply);
      }
    }

    for (final reply in replies) {
      addRecursively(reply);
    }
    return flatList;
  }

  Widget _buildReplyButton(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onReply(widget.comment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reply,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Reply',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final hasReplies = comment.replies.isNotEmpty;
    final replyCount = comment.repliesCount ?? comment.replies.length;
    const avatarRadius = 20.0;
    final horizontalPadding = widget.depth == 0 ? 20.0 : 36.0;
    final flatReplies = _flattenReplies(comment.replies);

    return Container(
      decoration: BoxDecoration(
        border: widget.depth == 0
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 12.0, 20.0, 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: Container(
                    width: avatarRadius * 2,
                    height: avatarRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.3),
                          theme.colorScheme.secondary.withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius - 1,
                      // FIX: Ensure the background color respects the current theme
                      backgroundColor: theme.colorScheme.surface,
                      child: CircleAvatar(
                        radius: avatarRadius - 2,
                        backgroundImage: comment.avatarUrl != null
                            ? CachedNetworkImageProvider(comment.avatarUrl!)
                            : null,
                        child: comment.avatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: 16,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with username and time
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProfile(context),
                            child: Text(
                              comment.username ?? 'Anonymous',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(
                              comment.createdAt,
                              locale: 'en_short',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Reply mention
                      if (comment.parentUsername != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text.rich(
                            TextSpan(
                              text: 'Replying to ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                              children: [
                                TextSpan(
                                  text: '@${comment.parentUsername}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Comment text
                      Text(
                        comment.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Actions row
                      Row(
                        children: [
                          _buildReplyButton(context),
                          const SizedBox(width: 12),
                          if (hasReplies && widget.depth < 1)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isRepliesExpanded = !_isRepliesExpanded;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isRepliesExpanded
                                      ? theme.colorScheme.primary.withOpacity(
                                          0.1,
                                        )
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isRepliesExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 16,
                                      color: _isRepliesExpanded
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _isRepliesExpanded
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                      .withOpacity(0.6),
                                          ),
                                    ),
                                  ],
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
          // Replies section
          if (hasReplies && widget.depth < 1)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !_isRepliesExpanded
                  ? const SizedBox.shrink()
                  : Container(
                      margin: EdgeInsets.only(left: horizontalPadding),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: flatReplies.map((reply) {
                          return CommentTile(
                            key: ValueKey(reply.id),
                            comment: reply,
                            onReply: widget.onReply,
                            depth: 1,
                            currentUserId: widget.currentUserId,
                          );
                        }).toList(),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
