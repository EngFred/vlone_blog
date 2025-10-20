import 'package:flutter/material.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FeedList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;

  const FeedList({super.key, required this.posts, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      key: const PageStorageKey('feed_list'),
      cacheExtent: 1500.0,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostCard(key: ValueKey(post.id), post: post, userId: userId);
      },
    );
  }
}
