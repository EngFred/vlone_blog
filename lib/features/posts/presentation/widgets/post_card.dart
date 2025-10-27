import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_actions.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_media.dart';

class PostCard extends StatefulWidget {
  final PostEntity post;
  final String userId;

  const PostCard({super.key, required this.post, required this.userId});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const double _kMediaDefaultHeight = 420.0;
  // local copy of the post so we can mutate quickly on optimistic updates
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent updates the post (e.g., server real-time), accept it
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<PostsBloc>(),
      child: MultiBlocListener(
        listeners: [
          // Likes listener (keeps previous behavior)
          BlocListener<LikesBloc, LikesState>(
            listenWhen: (prev, curr) {
              // Only listen for updates/error for this post
              if (curr is LikeUpdated && curr.postId == _currentPost.id)
                return true;
              if (curr is LikeError &&
                  curr.postId == _currentPost.id &&
                  curr.shouldRevert)
                return true;
              return false;
            },
            listener: (context, state) {
              if (state is LikeUpdated && state.postId == _currentPost.id) {
                AppLogger.info(
                  'PostCard received LikeUpdated for post: ${_currentPost.id}. Applying optimistic/server-corrected update.',
                );
                setState(() {
                  // apply isLiked directly
                  final newIsLiked = state.isLiked;
                  // adjust likes count by delta, ensure non-negative
                  final newLikesCount = (_currentPost.likesCount + state.delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  _currentPost = _currentPost.copyWith(
                    isLiked: newIsLiked,
                    likesCount: newLikesCount,
                  );
                });
              } else if (state is LikeError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                AppLogger.info(
                  'PostCard received LikeError for post: ${_currentPost.id}. Reverting UI.',
                );
                setState(() {
                  // revert to previousState and reverse the optimistic delta
                  final prev = state.previousState;
                  final revertedLikes = (_currentPost.likesCount - state.delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  _currentPost = _currentPost.copyWith(
                    isLiked: prev,
                    likesCount: revertedLikes,
                  );
                });
              }
            },
          ),

          // FAVORITES listener - FIXED listenWhen to include errors
          BlocListener<FavoritesBloc, FavoritesState>(
            listenWhen: (prev, curr) {
              // Allow both success updates and error-with-revert for this post
              if (curr is FavoriteUpdated && curr.postId == _currentPost.id)
                return true;
              if (curr is FavoriteError &&
                  curr.postId == _currentPost.id &&
                  curr.shouldRevert)
                return true;
              return false;
            },
            listener: (context, state) {
              if (state is FavoriteUpdated && state.postId == _currentPost.id) {
                // Single place that applies optimistic/server-corrected delta to local post
                setState(() {
                  final newIsFav = state.isFavorited;
                  final newFavoritesCount = newIsFav
                      ? _currentPost.favoritesCount +
                            (state.delta != 0 ? state.delta : 0)
                      : (_currentPost.favoritesCount > 0
                            ? _currentPost.favoritesCount -
                                  (state.delta != 0 ? state.delta : 0)
                            : 0);
                  _currentPost = _currentPost.copyWith(
                    isFavorited: newIsFav,
                    favoritesCount: newFavoritesCount,
                  );
                });
              } else if (state is FavoriteError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                // Revert the optimistic update centrally
                setState(() {
                  final prev = state.previousState;
                  final revertedCount = prev
                      ? _currentPost.favoritesCount +
                            (state.delta != 0 ? state.delta : 0)
                      : (_currentPost.favoritesCount > 0
                            ? _currentPost.favoritesCount -
                                  (state.delta != 0 ? state.delta : 0)
                            : 0);
                  _currentPost = _currentPost.copyWith(
                    isFavorited: prev,
                    favoritesCount: revertedCount,
                  );
                });
              }
            },
          ),
        ],
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostHeader(post: _currentPost, currentUserId: widget.userId),
              if (_currentPost.content != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Text(_currentPost.content!),
                ),
              if (_currentPost.mediaUrl != null) const SizedBox(height: 8),
              if (_currentPost.mediaUrl != null)
                PostMedia(post: _currentPost, height: _kMediaDefaultHeight),
              const SizedBox(height: 8),
              PostActions(post: _currentPost, userId: widget.userId),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
