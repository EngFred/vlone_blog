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
    final postId = post.id;
    context.read<PostsBloc>().add(SharePostEvent(postId));
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        // Spread the main actions to the left and favorite to the right
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // ================== LIKE BUTTON FIX ==================
              BlocBuilder<LikesBloc, LikesState>(
                // Only rebuild if the state update is for THIS post
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
                  // We let the PostsBloc's real-time stream update the count,
                  // which fixes the "count updates but icon doesn't" bug.
                  // This builder is only responsible for the icon's boolean state.

                  return DebouncedInkWell(
                    actionKey: 'like_${post.id}',
                    duration: _defaultDebounce,
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
                        if (likesCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            // Use the count from the PostEntity
                            child: Text(likesCount.toString()),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // ================ END LIKE BUTTON FIX ================
              const SizedBox(width: 20),

              // Comment (DebouncedInkWell)
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

              // Share (DebouncedInkWell)
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

          // ================== FAVORITE BUTTON FIX ==================
          BlocBuilder<FavoritesBloc, FavoritesState>(
            // Only rebuild if the state update is for THIS post
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
              // 1. Get baseline state from the PostEntity
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

              // 3. Count is handled by PostsBloc real-time stream.

              return DebouncedInkWell(
                actionKey: 'favorite_${post.id}',
                duration: _defaultDebounce,
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
          // =============== END FAVORITE BUTTON FIX ===============
        ],
      ),
    );
  }
}
