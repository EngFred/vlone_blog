import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/presentation/widgets/list_load_more_error_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/load_more_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/end_of_list_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/common/post_card.dart';

class FeedList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool hasMore;
  final bool isRealtimeActive;
  final VoidCallback? onLoadMore;
  final String? loadMoreError;
  final ScrollController? controller;
  final bool showEndOfList;

  const FeedList({
    super.key,
    required this.posts,
    required this.userId,
    this.hasMore = false,
    this.isRealtimeActive = false,
    this.onLoadMore,
    this.loadMoreError,
    this.controller,
    this.showEndOfList = true,
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
        if (hasMore) _buildLoadMoreFooter(context),
        if (!hasMore && showEndOfList && posts.isNotEmpty)
          _buildEndOfListFooter(context),
      ],
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    if (loadMoreError != null) {
      return SliverToBoxAdapter(
        child: LoadMoreErrorIndicator(
          message: loadMoreError!,
          onRetry: onLoadMore ?? () {},
          horizontalMargin: 16.0,
        ),
      );
    }

    return SliverToBoxAdapter(
      child: LoadMoreIndicator(
        message: 'Loading more posts...',
        indicatorSize: 20.0,
        spacing: 12.0,
      ),
    );
  }

  Widget _buildEndOfListFooter(BuildContext context) {
    return SliverToBoxAdapter(
      child: EndOfListIndicator(
        message: "You've reached the end",
        icon: Icons.flag_outlined,
        iconSize: 24.0,
        spacing: 12.0,
      ),
    );
  }
}
