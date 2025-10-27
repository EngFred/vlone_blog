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
        // ================== LIKE BUTTON FIX ==================
        BlocBuilder<LikesBloc, LikesState>(
          // Only rebuild if the state update is for THIS post
          buildWhen: (prev, curr) {
            if (curr is LikesInitial) return true;
            if (curr is LikeUpdated && curr.postId == post.id) return true;
            if (curr is LikeError &&
                curr.postId == post.id &&
                curr.shouldRevert)
              return true;
            return false;
          },
          builder: (context, state) {
            // 1. Get baseline state from the PostEntity (from PostsBloc)
            bool isLiked = post.isLiked;
            int likesCount = post.likesCount;

            // 2. Override with optimistic state from LikesBloc if it exists
            if (state is LikeUpdated && state.postId == post.id) {
              isLiked = state.isLiked;
            } else if (state is LikeError &&
                state.postId == post.id &&
                state.shouldRevert) {
              isLiked = state.previousState;
            }

            // 3. The likesCount is purposefully NOT updated optimistically here.
            // We let the PostsBloc's real-time stream update the count.
            // This builder is only responsible for the icon's boolean state.

            return DebouncedInkWell(
              actionKey: 'reel_like_${post.id}',
              duration: _debounce,
              onTap: () {
                // 4. Send the *inverse* of the *current UI state*
                context.read<LikesBloc>().add(
                  LikePostEvent(
                    postId: post.id,
                    userId: userId,
                    isLiked: !isLiked, // Use the derived 'isLiked'
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 32,
                  ),
                  Text(
                    '$likesCount', // Use count from PostEntity
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // ================ END LIKE BUTTON FIX ================
        const SizedBox(height: 20),

        // Comment (No state logic, this is fine)
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

        // ================== FAVORITE BUTTON FIX ==================
        BlocBuilder<FavoritesBloc, FavoritesState>(
          // Only rebuild if the state update is for THIS post
          buildWhen: (prev, curr) {
            if (curr is FavoritesInitial) return true;
            if (curr is FavoriteUpdated && curr.postId == post.id) return true;
            if (curr is FavoriteError &&
                curr.postId == post.id &&
                curr.shouldRevert)
              return true;
            return false;
          },
          builder: (context, state) {
            // 1. Get baseline state from PostEntity
            bool isFavorited = post.isFavorited;
            int favoritesCount = post.favoritesCount;

            // 2. Override with optimistic state from FavoritesBloc
            if (state is FavoriteUpdated && state.postId == post.id) {
              isFavorited = state.isFavorited;
            } else if (state is FavoriteError &&
                state.postId == post.id &&
                state.shouldRevert) {
              isFavorited = state.previousState;
            }

            // 3. Count (favoritesCount) is handled by PostsBloc stream via PostEntity

            return DebouncedInkWell(
              actionKey: 'reel_fav_${post.id}',
              duration: _debounce,
              onTap: () {
                // 4. Send the *inverse* of the *current UI state*
                context.read<FavoritesBloc>().add(
                  FavoritePostEvent(
                    postId: post.id,
                    userId: userId,
                    isFavorited: !isFavorited, // Use derived 'isFavorited'
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  Icon(
                    isFavorited ? Icons.bookmark : Icons.bookmark_border,
                    color: isFavorited ? Colors.amber : Colors.white,
                    size: 32,
                  ),
                  Text(
                    '$favoritesCount', // Use count from PostEntity
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // =============== END FAVORITE BUTTON FIX ===============
        const SizedBox(height: 20),

        // Share (No state logic, this is fine)
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
