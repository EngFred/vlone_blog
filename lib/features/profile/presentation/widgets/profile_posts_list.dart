import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class ProfilePostsList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onRetry;

  const ProfilePostsList({
    super.key,
    required this.posts,
    required this.userId,
    required this.isLoading,
    required this.onRetry,
    this.error,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreError,
  });

  // Pass BuildContext as an argument
  Widget _buildLoadMoreFooter(BuildContext context) {
    if (loadMoreError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'Failed to load more posts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.read<UserPostsBloc>().add(
                const LoadMoreUserPostsEvent(), // Assuming LoadMoreUserPostsEvent is const
              ),
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

    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              LoadingIndicator(size: 20),
              SizedBox(height: 8),
              Text(
                'Loading more posts...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: const Column(
            children: [
              LoadingIndicator(size: 32),
              SizedBox(height: 16),
              Text(
                'Loading posts...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: EmptyStateWidget(
            message: error!,
            icon: Icons.error_outline,
            onRetry: onRetry,
            actionText: 'Retry',
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: EmptyStateWidget(
            message: 'No posts yet',
            icon: Icons.post_add,
            actionText: 'Create Post',
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < posts.length) {
          final post = posts[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: PostCard(key: ValueKey(post.id), post: post, userId: userId),
          );
        } else {
          // Call the helper method with the local context
          return _buildLoadMoreFooter(context);
        }
      }, childCount: posts.length + (hasMore || loadMoreError != null ? 1 : 0)),
    );
  }
}
