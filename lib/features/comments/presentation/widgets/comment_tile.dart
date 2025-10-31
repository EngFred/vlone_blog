import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';

//Used both on post details and reels comments in bottom sheet
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _navigateToProfile(BuildContext context) {
    if (widget.comment.userId == widget.currentUserId) {
      context.go('${Constants.profileRoute}/me');
    } else {
      context.push('${Constants.profileRoute}/${widget.comment.userId}');
    }
  }

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
    final replyCount = comment.repliesCount ?? comment.replies.length;
    final replyText = replyCount == 1 ? 'reply' : 'replies';
    const avatarRadius = 20.0;
    final horizontalPadding = widget.depth == 0 ? 16.0 : 40.0;
    final flatReplies = _flattenReplies(comment.replies);

    return Container(
      // Highlighting logic removed, using base canvas color.
      decoration: BoxDecoration(color: theme.canvasColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8.0, 16.0, 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundImage: comment.avatarUrl != null
                        ? CachedNetworkImageProvider(comment.avatarUrl!)
                        : null,
                    child: comment.avatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProfile(context),
                            child: Text(
                              comment.username ?? 'Anonymous',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${timeago.format(comment.createdAt, locale: 'en_short')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                      Text(comment.text, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
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
                          if (hasReplies && widget.depth < 1)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isRepliesExpanded = !_isRepliesExpanded;
                                });
                              },
                              child: Text(
                                _isRepliesExpanded
                                    ? 'Hide $replyCount $replyText'
                                    : 'View $replyCount $replyText',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
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
          if (widget.depth == 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(height: 1, indent: 50),
            ),
          if (hasReplies && widget.depth < 1)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !_isRepliesExpanded
                  ? const SizedBox.shrink()
                  : Column(
                      children: flatReplies.map((reply) {
                        // Use ValueKey now that GlobalKeys are not needed
                        final replyKey = ValueKey(reply.id);

                        return CommentTile(
                          key: replyKey,
                          comment: reply,
                          onReply: widget.onReply,
                          depth: 1,
                          currentUserId: widget.currentUserId,
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}
