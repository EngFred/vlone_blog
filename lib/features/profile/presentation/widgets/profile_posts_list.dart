import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/list_load_more_error_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/load_more_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/end_of_list_indicator.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/common/post_card.dart';

class ProfilePostsList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onRetry;
  final bool showEndOfList;

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
    this.showEndOfList = true,
  });

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

    if (error != null && posts.isEmpty) {
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
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < posts.length) {
            final post = posts[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                userId: userId,
              ),
            );
          } else if (hasMore) {
            // Load more indicator or error
            if (loadMoreError != null) {
              return LoadMoreErrorIndicator(
                message: loadMoreError!,
                onRetry: () {
                  context.read<UserPostsBloc>().add(
                    const LoadMoreUserPostsEvent(),
                  );
                },
                horizontalMargin: 16.0,
              );
            } else {
              return LoadMoreIndicator(
                message: 'Loading more posts...',
                indicatorSize: 20.0,
                spacing: 12.0,
              );
            }
          } else if (showEndOfList) {
            return EndOfListIndicator(
              message: "You've reached the end",
              icon: Icons.flag_outlined,
              iconSize: 24.0,
              spacing: 12.0,
            );
          } else {
            return const SizedBox.shrink();
          }
        },
        childCount:
            posts.length + (hasMore || (!hasMore && showEndOfList) ? 1 : 0),
      ),
    );
  }
}
