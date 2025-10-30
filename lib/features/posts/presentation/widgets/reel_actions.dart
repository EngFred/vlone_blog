import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';

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
        // NOTE: The consuming widget (ReelsPage) must now provide the correct BLoC
        // to this modal (e.g., CommentsBloc/PostActionsBloc for the details).
        // Since we don't know the list bloc for reels, we remove the BlocProvider.value here.
        return ReelsCommentsOverlay(post: post, userId: userId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use post as authoritative source-of-truth for counts.
    final baseIsLiked = post.isLiked;
    final baseLikesCount = post.likesCount;
    final baseIsFavorited = post.isFavorited;
    final baseCommentsCount = post.commentsCount;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // ==================== LIKE BUTTON ====================
        BlocBuilder<LikesBloc, LikesState>(
          buildWhen: (prev, curr) {
            if (curr is LikesInitial) return true;
            if (curr is LikeUpdated && curr.postId == post.id) return true;
            if (curr is LikeError &&
                curr.postId == post.id &&
                curr.shouldRevert) {
              return true;
            }
            return false;
          },
          builder: (context, state) {
            // Show icon state from LikesBloc if provided, but counts only from post
            bool isLiked = baseIsLiked;
            int likesCount = baseLikesCount;

            if (state is LikeUpdated && state.postId == post.id) {
              isLiked = state.isLiked;
            } else if (state is LikeError &&
                state.postId == post.id &&
                state.shouldRevert) {
              isLiked = state.previousState;
            }

            return DebouncedInkWell(
              actionKey: 'reel_like_${post.id}',
              duration: _debounce,
              onTap: () {
                // Fire domain action
                context.read<LikesBloc>().add(
                  LikePostEvent(
                    postId: post.id,
                    userId: userId,
                    isLiked: !isLiked,
                    previousState: isLiked,
                  ),
                );

                // ✅ CHANGE 1: Dispatch OptimisticPostUpdate to PostActionsBloc
                final int delta = (!isLiked) ? 1 : -1;
                context.read<PostActionsBloc>().add(
                  OptimisticPostUpdate(
                    postId: post.id,
                    deltaLikes: delta,
                    deltaFavorites: 0,
                    isLiked: !isLiked,
                    isFavorited: null,
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
                  // ALWAYS show the likes count (including 0) — consistent with feed likes.
                  Text(
                    likesCount.toString(),
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
        const SizedBox(height: 20),

        // ==================== COMMENT BUTTON ====================
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
              // **COMMENTS: keep original behavior** — only show the number when > 0,
              // because comments are not part of optimistic updates and rely on realtime.
              if (baseCommentsCount > 0)
                Text(
                  baseCommentsCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ==================== FAVORITE BUTTON ====================
        BlocBuilder<FavoritesBloc, FavoritesState>(
          buildWhen: (prev, curr) {
            if (curr is FavoritesInitial) return true;
            if (curr is FavoriteUpdated && curr.postId == post.id) return true;
            if (curr is FavoriteError &&
                curr.postId == post.id &&
                curr.shouldRevert) {
              return true;
            }
            return false;
          },
          builder: (context, state) {
            bool isFavorited = baseIsFavorited;
            int favoritesCount = post.favoritesCount;

            if (state is FavoriteUpdated && state.postId == post.id) {
              isFavorited = state.isFavorited;
            } else if (state is FavoriteError &&
                state.postId == post.id &&
                state.shouldRevert) {
              isFavorited = state.previousState;
            }

            return DebouncedInkWell(
              actionKey: 'reel_fav_${post.id}',
              duration: _debounce,
              onTap: () {
                // Fire domain action
                context.read<FavoritesBloc>().add(
                  FavoritePostEvent(
                    postId: post.id,
                    userId: userId,
                    isFavorited: !isFavorited,
                    previousState: isFavorited,
                  ),
                );

                // ✅ CHANGE 2: Dispatch OptimisticPostUpdate to PostActionsBloc
                final int deltaFav = (!isFavorited) ? 1 : -1;
                context.read<PostActionsBloc>().add(
                  OptimisticPostUpdate(
                    postId: post.id,
                    deltaLikes: 0,
                    deltaFavorites: deltaFav,
                    isLiked: null,
                    isFavorited: !isFavorited,
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
                  // ALWAYS show favorites count (including 0)
                  Text(
                    favoritesCount.toString(),
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
        const SizedBox(height: 20),

        // ==================== SHARE BUTTON ====================
        DebouncedInkWell(
          actionKey: 'reel_share_${post.id}',
          duration: _debounce,
          onTap: () {
            AppLogger.info('Share button tapped for post: ${post.id}');
            context.read<PostActionsBloc>().add(SharePostEvent(post.id));
          },
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: const Icon(Icons.share, color: Colors.white, size: 32),
        ),
      ],
    );
  }
}
