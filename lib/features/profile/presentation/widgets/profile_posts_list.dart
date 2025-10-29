import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class ProfilePostsList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool isLoading;
  final String? error;
  final bool hasMore; // Added
  final bool isLoadingMore; // Added
  final String? loadMoreError; // Added
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: LoadingIndicator(),
      );
    }
    if (error != null) {
      return EmptyStateWidget(
        message: error!,
        icon: Icons.error_outline,
        onRetry: onRetry,
        actionText: 'Retry',
      );
    }
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: EmptyStateWidget(
          message: 'This user has no posts yet.',
          icon: Icons.post_add,
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: false, // Changed: Allow full height
      physics: const ClampingScrollPhysics(), // Changed: Allow scrolling
      cacheExtent: 1500.0,
      itemCount:
          posts.length +
          (hasMore || loadMoreError != null ? 1 : 0), // Added: +1 for footer
      itemBuilder: (context, index) {
        if (index < posts.length) {
          final post = posts[index];
          return PostCard(key: ValueKey(post.id), post: post, userId: userId);
        } else {
          // Added: Footer for loading more or error
          if (loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    loadMoreError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  ElevatedButton(
                    onPressed: onRetry, // Reuse onRetry for load more retry
                    child: const Text('Retry Loading More'),
                  ),
                ],
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: LoadingIndicator(),
          );
        }
      },
    );
  }
}
