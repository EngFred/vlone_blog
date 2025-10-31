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
  final ScrollController? controller;

  const FeedList({
    super.key,
    required this.posts,
    required this.userId,
    this.hasMore = false,
    this.isRealtimeActive = false,
    this.onLoadMore,
    this.loadMoreError,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return CustomScrollView(
      key: const PageStorageKey('feed_list'),
      controller: controller,
      cacheExtent: 1500.0,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final post = posts[index];
            return PostCard(key: ValueKey(post.id), post: post, userId: userId);
          }, childCount: posts.length),
        ),
        if (hasMore) SliverToBoxAdapter(child: _buildLoadMoreFooter(context)),
      ],
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    if (loadMoreError != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              loadMoreError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onLoadMore,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: Column(
          children: [
            LoadingIndicator(size: 20),
            SizedBox(height: 12),
            Text(
              'Loading more posts...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
