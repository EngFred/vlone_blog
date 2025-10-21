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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(post: post),
          if (post.content != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(post.content!),
            ),
          if (post.mediaUrl != null)
            PostMedia(post: post, height: detailsMediaHeight, autoPlay: false),
          PostActions(post: post, userId: userId, onCommentTap: onCommentTap),
          const Divider(),
        ],
      ),
    );
  }
}
