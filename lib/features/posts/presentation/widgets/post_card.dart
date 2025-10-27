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
  // Use a local mutable variable to hold the current post state
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  // Update the local state if the parent's widget.post changes (e.g., from a realtime post update)
  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<PostsBloc>(),
      // Add MultiBlocListener here to listen for optimistic updates
      child: MultiBlocListener(
        listeners: [
          BlocListener<LikesBloc, LikesState>(
            listenWhen: (prev, current) =>
                current is LikeUpdated && current.postId == _currentPost.id,
            listener: (context, state) {
              if (state is LikeUpdated) {
                AppLogger.info(
                  'PostCard received LikeUpdated for post: ${_currentPost.id}. Optimistic UI change.',
                );
                setState(() {
                  _currentPost = _currentPost.copyWith(
                    isLiked: state.isLiked,
                    // Increment/decrement the count to reflect the optimistic update
                    likesCount: state.isLiked
                        ? _currentPost.likesCount + 1
                        : _currentPost.likesCount > 0
                        ? _currentPost.likesCount - 1
                        : 0,
                  );
                });
              } else if (state is LikeError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                AppLogger.info(
                  'PostCard received LikeError for post: ${_currentPost.id}. Reverting UI.',
                );
                // Revert the state on error
                setState(() {
                  _currentPost = _currentPost.copyWith(
                    isLiked: state.previousState,
                    // Revert count as well
                    likesCount: state.previousState
                        ? _currentPost.likesCount + 1
                        : _currentPost.likesCount > 0
                        ? _currentPost.likesCount - 1
                        : 0,
                  );
                });
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listenWhen: (prev, current) =>
                current is FavoriteUpdated && current.postId == _currentPost.id,
            listener: (context, state) {
              if (state is FavoriteUpdated) {
                AppLogger.info(
                  'PostCard received FavoriteUpdated for post: ${_currentPost.id}. Optimistic UI change.',
                );
                setState(() {
                  _currentPost = _currentPost.copyWith(
                    isFavorited: state.isFavorited,
                    favoritesCount: state.isFavorited
                        ? _currentPost.favoritesCount + 1
                        : _currentPost.favoritesCount > 0
                        ? _currentPost.favoritesCount - 1
                        : 0,
                  );
                });
              } else if (state is FavoriteError &&
                  state.postId == _currentPost.id &&
                  state.shouldRevert) {
                AppLogger.info(
                  'PostCard received FavoriteError for post: ${_currentPost.id}. Reverting UI.',
                );
                // Revert the state on error
                setState(() {
                  _currentPost = _currentPost.copyWith(
                    isFavorited: state.previousState,
                    // Revert count as well
                    favoritesCount: state.previousState
                        ? _currentPost.favoritesCount + 1
                        : _currentPost.favoritesCount > 0
                        ? _currentPost.favoritesCount - 1
                        : 0,
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
                PostMedia(
                  post: _currentPost,
                  // Apply default height for non-reels so images match videos
                  height: _kMediaDefaultHeight,
                ),
              const SizedBox(height: 8),
              // Use the local state here
              PostActions(post: _currentPost, userId: widget.userId),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
