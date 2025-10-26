import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels_comments_overlay.dart';

class ReelActions extends StatelessWidget {
  final PostEntity post;
  final String userId;

  const ReelActions({super.key, required this.post, required this.userId});

  static const Duration _debounce = Duration(milliseconds: 500);

  void _showCommentsOverlay(BuildContext context) {
    AppLogger.info('Opening comments overlay for post: ${post.id}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return BlocProvider.value(
          value: context.read<PostsBloc>(),
          child: ReelsCommentsOverlay(post: post, userId: userId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Each icon + label is now debounced via DebouncedInkWell
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Like
        DebouncedInkWell(
          actionKey: 'reel_like_${post.id}',
          duration: _debounce,
          onTap: () {
            context.read<LikesBloc>().add(
              LikePostEvent(
                postId: post.id,
                userId: userId,
                isLiked: !post.isLiked,
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              Icon(
                post.isLiked ? Icons.favorite : Icons.favorite_border,
                color: post.isLiked ? Colors.red : Colors.white,
                size: 32,
              ),
              Text(
                '${post.likesCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Comment
        DebouncedInkWell(
          actionKey: 'reel_comment_${post.id}',
          duration: _debounce,
          onTap: () => _showCommentsOverlay(context),
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 32,
              ),
              Text(
                '${post.commentsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Favorite
        DebouncedInkWell(
          actionKey: 'reel_fav_${post.id}',
          duration: _debounce,
          onTap: () {
            context.read<FavoritesBloc>().add(
              FavoritePostEvent(
                postId: post.id,
                userId: userId,
                isFavorited: !post.isFavorited,
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              Icon(
                post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
                color: post.isFavorited ? Colors.amber : Colors.white,
                size: 32,
              ),
              Text(
                '${post.favoritesCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Share
        DebouncedInkWell(
          actionKey: 'reel_share_${post.id}',
          duration: _debounce,
          onTap: () {
            AppLogger.info('Share button tapped for post: ${post.id}');
            context.read<PostsBloc>().add(SharePostEvent(post.id));
          },
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: const Icon(Icons.share, color: Colors.white, size: 32),
        ),
      ],
    );
  }
}
