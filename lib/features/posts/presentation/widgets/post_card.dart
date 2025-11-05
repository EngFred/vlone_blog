import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/expandable_text.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_actions.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';

// Converted to StatelessWidget
class PostCard extends StatelessWidget {
  final PostEntity post;
  final String userId;

  const PostCard({super.key, required this.post, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All widgets now just use the 'post' prop directly
          PostHeader(post: post, currentUserId: userId),
          if (post.content != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: ExpandableText(
                text: post.content!,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
                collapsedMaxLines: 3,
              ),
            ),
          if (post.mediaUrl != null) const SizedBox(height: 4),
          if (post.mediaUrl != null) PostMedia(post: post),
          const SizedBox(height: 8),
          PostActions(post: post, userId: userId),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
