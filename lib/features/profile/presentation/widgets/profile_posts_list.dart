import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class ProfilePostsList extends StatelessWidget {
  final List<PostEntity> posts;
  final String userId;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const ProfilePostsList({
    super.key,
    required this.posts,
    required this.userId,
    required this.isLoading,
    required this.onRetry,
    this.error,
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: CustomErrorWidget(message: error!, onRetry: onRetry),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      cacheExtent: 1500.0,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostCard(key: ValueKey(post.id), post: post, userId: userId);
      },
    );
  }
}
