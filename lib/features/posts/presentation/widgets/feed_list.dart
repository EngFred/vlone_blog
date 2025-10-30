import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FeedList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool hasMore;
  final bool isRealtimeActive;
  final VoidCallback? onLoadMore;
  final String? loadMoreError;
  final ScrollController? controller; // NEW

  const FeedList({
    super.key,
    required this.posts,
    required this.userId,
    this.hasMore = false,
    this.isRealtimeActive = false,
    this.onLoadMore,
    this.loadMoreError,
    this.controller, // NEW
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      key: const PageStorageKey('feed_list'),
      controller:
          controller, // ATTACH controller so outer ScrollController receives events
      cacheExtent: 1500.0,
      itemCount:
          posts.length +
          (hasMore ? 1 : 0), // Extra item for loading footer if hasMore
      itemBuilder: (context, index) {
        if (index == posts.length) {
          // Loading footer if hasMore
          if (loadMoreError != null) {
            return ListTile(title: Text(loadMoreError!), onTap: onLoadMore);
          }
          return const ListTile(title: Center(child: LoadingIndicator()));
        }
        final post = posts[index];
        return PostCard(key: ValueKey(post.id), post: post, userId: userId);
      },
    );
  }
}
