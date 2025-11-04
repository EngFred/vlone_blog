import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_overlay.dart';

class PostActions extends StatelessWidget {
  final PostEntity post;
  final String userId;
  final VoidCallback? onCommentTap;

  /// When false, the comments *count* will not be shown (only the comment icon).
  /// Used by PostDetailsPage where the comments section / input already shows counts.
  final bool showCommentsCount;

  const PostActions({
    super.key,
    required this.post,
    required this.userId,
    this.onCommentTap,
    this.showCommentsCount = true,
  });

  static const Duration _defaultDebounce = Duration(milliseconds: 500);
  static const double _kActionIconSize = 26.0;

  // Update _share to use PostActionsBloc
  void _share(BuildContext context) {
    context.read<PostActionsBloc>().add(SharePostEvent(post.id));
  }

  // UPDATED: Replaced navigation with bottom sheet overlay
  void _handleComment(BuildContext context) {
    if (onCommentTap != null) {
      onCommentTap!();
    } else {
      // OLD: context.push('${Constants.postDetailsRoute}/${post.id}', extra: post);
      // NEW: Show the bottom sheet overlay
      CommentsOverlay.show(context, post, userId);
    }
  }

  Widget _buildActionItem({
    required Widget icon,
    String? count,
    required VoidCallback onTap,
    required String actionKey,
  }) {
    // UI/UX: Helper function for consistent action button styling
    return DebouncedInkWell(
      actionKey: actionKey,
      duration: _defaultDebounce,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0), // Rounded for modern touch
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0, // Increased horizontal padding
        vertical: 4.0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              // UI/UX: Use titleSmall for more distinct and readable count text
              child: Text(count),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  if (curr is LikeUpdated && curr.postId == post.id) {
                    return true;
                  }
                  if (curr is LikeError &&
                      curr.postId == post.id &&
                      curr.shouldRevert) {
                    return true;
                  }
                  return false;
                },
                builder: (context, state) {
                  bool isLiked = post.isLiked;
                  if (state is LikeUpdated && state.postId == post.id) {
                    isLiked = state.isLiked;
                  } else if (state is LikeError &&
                      state.postId == post.id &&
                      state.shouldRevert) {
                    isLiked = state.previousState;
                  }

                  return _buildActionItem(
                    actionKey: 'like_${post.id}',
                    count: baseLikesCount.toString(),
                    onTap: () {
                      context.read<LikesBloc>().add(
                        LikePostEvent(
                          postId: post.id,
                          userId: userId,
                          isLiked: !isLiked,
                          previousState: isLiked,
                        ),
                      );

                      final int delta = (!isLiked) ? 1 : -1;
                      context.read<PostActionsBloc>().add(
                        OptimisticPostUpdate(
                          post: post,
                          deltaLikes: delta,
                          deltaFavorites: 0,
                          isLiked: !isLiked,
                        ),
                      );
                    },
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: _kActionIconSize,
                      color: isLiked ? Colors.red.shade600 : null,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16), // UI/UX: Reduced space
              // ==================== COMMENT BUTTON ====================
              _buildActionItem(
                actionKey: 'comment_nav_${post.id}',
                count: showCommentsCount ? baseCommentsCount.toString() : null,
                onTap: () => _handleComment(context),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: _kActionIconSize,
                ),
              ),
              const SizedBox(width: 16), // UI/UX: Reduced space
              // ==================== SHARE BUTTON ====================
              _buildActionItem(
                actionKey: 'share_${post.id}',
                count: 'Share', // UI/UX: Label instead of count
                onTap: () => _share(context),
                icon: const Icon(Icons.send_outlined, size: _kActionIconSize),
              ),
            ],
          ),

          // ==================== FAVORITE BUTTON (BLOC) ====================
          BlocBuilder<FavoritesBloc, FavoritesState>(
            buildWhen: (prev, curr) {
              if (curr is FavoritesInitial) return true;
              if (curr is FavoriteUpdated && curr.postId == post.id) {
                return true;
              }
              if (curr is FavoriteError &&
                  curr.postId == post.id &&
                  curr.shouldRevert) {
                return true;
              }
              return false;
            },
            builder: (context, state) {
              bool isFavorited = post.isFavorited;
              if (state is FavoriteUpdated && state.postId == post.id) {
                isFavorited = state.isFavorited;
              } else if (state is FavoriteError &&
                  state.postId == post.id &&
                  state.shouldRevert) {
                isFavorited = state.previousState;
              }

              return _buildActionItem(
                actionKey: 'favorite_${post.id}',
                count: baseFavoritesCount.toString(),
                onTap: () {
                  context.read<FavoritesBloc>().add(
                    FavoritePostEvent(
                      postId: post.id,
                      userId: userId,
                      isFavorited: !isFavorited,
                      previousState: isFavorited,
                    ),
                  );

                  final int deltaFav = (!isFavorited) ? 1 : -1;
                  context.read<PostActionsBloc>().add(
                    OptimisticPostUpdate(
                      post: post,
                      deltaFavorites: deltaFav,
                      isFavorited: !isFavorited,
                    ),
                  );
                },
                icon: Icon(
                  isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  size: _kActionIconSize,
                  color: isFavorited
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
