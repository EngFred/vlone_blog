import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';

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

  void _share(BuildContext context) {
    context.read<PostsBloc>().add(SharePostEvent(post.id));
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
    // Base values from PostEntity (from PostsBloc)
    final baseIsLiked = post.isLiked;
    final baseLikesCount = post.likesCount;
    final baseIsFavorited = post.isFavorited;
    final baseFavoritesCount = post.favoritesCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // ==================== LIKE BUTTON ====================
              DebouncedInkWell(
                actionKey: 'like_${post.id}',
                duration: _defaultDebounce,
                onTap: () {
                  // Fire the domain action
                  context.read<LikesBloc>().add(
                    LikePostEvent(
                      postId: post.id,
                      userId: userId,
                      isLiked: !baseIsLiked,
                      previousState: baseIsLiked,
                    ),
                  );

                  // Immediately update central posts list optimistically so pages/feeds reflect the change.
                  final int delta = (!baseIsLiked) ? 1 : -1;
                  context.read<PostsBloc>().add(
                    OptimisticPostUpdate(
                      postId: post.id,
                      deltaLikes: delta,
                      deltaFavorites: 0,
                      isLiked: !baseIsLiked,
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
                      baseIsLiked ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                    ),
                    if (baseLikesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(baseLikesCount.toString()),
                      ),
                  ],
                ),
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
                    if (post.commentsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(post.commentsCount.toString()),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.share_outlined, size: 24),
                    if (post.sharesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(post.sharesCount.toString()),
                      ),
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
              bool isFavorited = baseIsFavorited;
              int favoritesCount = baseFavoritesCount;

              if (state is FavoriteUpdated && state.postId == post.id) {
                isFavorited = state.isFavorited;
                // DO NOT apply state.delta here (PostCard handles local count).
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

                  // Immediately update central posts list optimistically
                  final int deltaFav = (!isFavorited) ? 1 : -1;
                  context.read<PostsBloc>().add(
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
                    if (favoritesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(favoritesCount.toString()),
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
