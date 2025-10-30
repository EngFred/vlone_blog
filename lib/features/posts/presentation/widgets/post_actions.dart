import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

// ✅ CHANGE 1: Import the new PostActionsBloc
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';

class PostActions extends StatelessWidget {
  final PostEntity post;
  final String userId;
  final VoidCallback? onCommentTap;

  const PostActions({
    super.key,
    required this.post,
    required this.userId,
    this.onCommentTap,
  });

  static const Duration _defaultDebounce = Duration(milliseconds: 500);

  // ✅ CHANGE 2: Update _share to use PostActionsBloc
  void _share(BuildContext context) {
    context.read<PostActionsBloc>().add(SharePostEvent(post.id));
  }

  void _handleComment(BuildContext context) {
    if (onCommentTap != null) {
      onCommentTap!();
    } else {
      context.push('${Constants.postDetailsRoute}/${post.id}', extra: post);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Base counts come from post (PostsBloc is authoritative).
    // Likes & favorites: always render the numeric count (including 0) to avoid layout shift.
    // Comments: left "as it were" — we DO NOT show a 0 count here because comments are not
    // part of the optimistic update flow and should rely on the realtime/source updates.
    final baseLikesCount = post.likesCount;
    final baseFavoritesCount = post.favoritesCount;
    final baseCommentsCount = post.commentsCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // ==================== LIKE BUTTON ====================
              BlocBuilder<LikesBloc, LikesState>(
                buildWhen: (prev, curr) {
                  if (curr is LikesInitial) return true;
                  if (curr is LikeUpdated && curr.postId == post.id)
                    return true;
                  if (curr is LikeError &&
                      curr.postId == post.id &&
                      curr.shouldRevert)
                    return true;
                  return false;
                },
                builder: (context, state) {
                  // Icon boolean may come from LikesBloc for snappy toggle, fallback to post.
                  bool isLiked = post.isLiked;
                  if (state is LikeUpdated && state.postId == post.id) {
                    isLiked = state.isLiked;
                  } else if (state is LikeError &&
                      state.postId == post.id &&
                      state.shouldRevert) {
                    isLiked = state.previousState;
                  }

                  return DebouncedInkWell(
                    actionKey: 'like_${post.id}',
                    duration: _defaultDebounce,
                    onTap: () {
                      // Fire the domain action to LikesBloc
                      context.read<LikesBloc>().add(
                        LikePostEvent(
                          postId: post.id,
                          userId: userId,
                          isLiked: !isLiked,
                          previousState: isLiked,
                        ),
                      );

                      // ✅ CHANGE 3: Dispatch OptimisticPostUpdate to PostActionsBloc
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
                    borderRadius: BorderRadius.circular(8.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 24,
                        ),
                        // ALWAYS show the count for likes (including 0) to avoid layout jump.
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Text(baseLikesCount.toString()),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 20),

              // ==================== COMMENT BUTTON ====================
              DebouncedInkWell(
                actionKey: 'comment_nav_${post.id}',
                duration: _defaultDebounce,
                onTap: () => _handleComment(context),
                borderRadius: BorderRadius.circular(8.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.comment_outlined, size: 24),
                    // **COMMENTS: keep original behavior** — only show the number when > 0.
                    if (baseCommentsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(baseCommentsCount.toString()),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // ==================== SHARE BUTTON ====================
              DebouncedInkWell(
                actionKey: 'share_${post.id}',
                duration: _defaultDebounce,
                onTap: () => _share(context),
                borderRadius: BorderRadius.circular(8.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: const Row(
                  // Now using const Row and no Text for the count
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_outlined, size: 24),
                    // Shares count display has been removed here.
                  ],
                ),
              ),
            ],
          ),

          // ==================== FAVORITE BUTTON (BLOC) ====================
          BlocBuilder<FavoritesBloc, FavoritesState>(
            buildWhen: (prev, curr) {
              if (curr is FavoritesInitial) return true;
              if (curr is FavoriteUpdated && curr.postId == post.id)
                return true;
              if (curr is FavoriteError &&
                  curr.postId == post.id &&
                  curr.shouldRevert)
                return true;
              return false;
            },
            builder: (context, state) {
              // Use post as source-of-truth for counts to avoid double-applying delta.
              bool isFavorited = post.isFavorited;

              if (state is FavoriteUpdated && state.postId == post.id) {
                isFavorited = state.isFavorited;
                // DO NOT apply delta here — PostsBloc must update counts.
              } else if (state is FavoriteError &&
                  state.postId == post.id &&
                  state.shouldRevert) {
                isFavorited = state.previousState;
              }

              return DebouncedInkWell(
                actionKey: 'favorite_${post.id}',
                duration: _defaultDebounce,
                onTap: () {
                  // Fire the domain action
                  context.read<FavoritesBloc>().add(
                    FavoritePostEvent(
                      postId: post.id,
                      userId: userId,
                      isFavorited: !isFavorited,
                      previousState: isFavorited,
                    ),
                  );

                  // ✅ CHANGE 4: Dispatch OptimisticPostUpdate to PostActionsBloc
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
                borderRadius: BorderRadius.circular(8.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFavorited ? Icons.bookmark : Icons.bookmark_border,
                      size: 24,
                    ),
                    // ALWAYS show favorites count (including 0) — matches likes behavior.
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Text(baseFavoritesCount.toString()),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
