import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels_comments_overlay.dart';

class ReelActions extends StatelessWidget {
  final PostEntity post;
  final String userId;

  const ReelActions({super.key, required this.post, required this.userId});

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Like button
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : Colors.white,
            size: 32,
          ),
          onPressed: () {
            context.read<LikesBloc>().add(
              LikePostEvent(
                postId: post.id,
                userId: userId,
                isLiked: !post.isLiked,
              ),
            );
          },
        ),
        Text(
          '${post.likesCount}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Comment button - FIXED
        IconButton(
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => _showCommentsOverlay(context),
        ),
        Text(
          '${post.commentsCount}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Favorite button
        IconButton(
          icon: Icon(
            post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
            color: post.isFavorited ? Colors.amber : Colors.white,
            size: 32,
          ),
          onPressed: () {
            context.read<FavoritesBloc>().add(
              FavoritePostEvent(
                postId: post.id,
                userId: userId,
                isFavorited: !post.isFavorited,
              ),
            );
          },
        ),
        Text(
          '${post.favoritesCount}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Share button
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white, size: 32),
          onPressed: () {
            AppLogger.info('Share button tapped for post: ${post.id}');
            // Share handled by PostsBloc (or move if you've refactored it)
            context.read<PostsBloc>().add(SharePostEvent(post.id));
          },
        ),
      ],
    );
  }
}
