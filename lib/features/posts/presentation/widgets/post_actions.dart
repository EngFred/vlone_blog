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

  void _toggleLike(BuildContext context) {
    final postId = post.id;
    final newLiked = !post.isLiked;
    context.read<LikesBloc>().add(
      LikePostEvent(postId: postId, userId: userId, isLiked: newLiked),
    );
  }

  void _toggleFavorite(BuildContext context) {
    final postId = post.id;
    final newFav = !post.isFavorited;
    context.read<FavoritesBloc>().add(
      FavoritePostEvent(postId: postId, userId: userId, isFavorited: newFav),
    );
  }

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
              // Like (DebouncedInkWell)
              DebouncedInkWell(
                actionKey: 'like_${post.id}',
                duration: _defaultDebounce,
                onTap: () => _toggleLike(context),
                borderRadius: BorderRadius.circular(8.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                    ),
                    if (post.likesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(post.likesCount.toString()),
                      ),
                  ],
                ),
              ),
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

          // Favorite/Bookmark (Pinned to the right) - DebouncedInkWell
          DebouncedInkWell(
            actionKey: 'favorite_${post.id}',
            duration: _defaultDebounce,
            onTap: () => _toggleFavorite(context),
            borderRadius: BorderRadius.circular(8.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  size: 24,
                ),
                if (post.favoritesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(post.favoritesCount.toString()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
