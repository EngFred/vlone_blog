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

class _CommentTileState extends State<CommentTile>
    with TickerProviderStateMixin {
  // default collapsed so replies are not built eagerly
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = (20 - (widget.depth * 2.0)).clamp(12.0, 20.0);

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: avatarRadius,
              backgroundImage: widget.comment.avatarUrl != null
                  ? CachedNetworkImageProvider(widget.comment.avatarUrl!)
                  : null,
              child: widget.comment.avatarUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              widget.comment.username ?? 'Anonymous',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.comment.text),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeago.format(
                        widget.comment.createdAt,
                        locale: 'en_short',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => widget.onReply(widget.comment),
                      child: Text(
                        'Reply',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.comment.replies.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Text(
                          _isExpanded
                              ? 'Hide ${widget.comment.replies.length} replies'
                              : 'View ${widget.comment.replies.length} replies',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Replies (animated & built only when expanded)
          if (widget.comment.replies.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 55.0),
                      child: Column(
                        children: widget.comment.replies
                            .map(
                              (reply) => CommentTile(
                                comment: reply,
                                onReply: widget.onReply,
                                depth: widget.depth + 1,
                              ),
                            )
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
