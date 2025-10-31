import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_actions.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';

class PostDetailsContent extends StatelessWidget {
  final PostEntity post;
  final String userId;
  final VoidCallback onCommentTap;
  const PostDetailsContent({
    super.key,
    required this.post,
    required this.userId,
    required this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final double detailsMediaHeight = MediaQuery.of(context).size.height * 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: PhysicalModel(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PostHeader(post: post, currentUserId: userId),
                if (post.content != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12,
                    ),
                    child: Text(
                      post.content!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                if (post.mediaUrl != null) const SizedBox(height: 4),
                if (post.mediaUrl != null)
                  PostMedia(
                    post: post,
                    height: detailsMediaHeight,
                    useVisibilityDetector: false,
                  ),
                PostActions(
                  post: post,
                  userId: userId,
                  onCommentTap: onCommentTap,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
