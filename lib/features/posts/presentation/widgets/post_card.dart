import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';

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
    // Accept authoritative updates from parent. Keep local copy synced.
    // This is typically coming from a FeedBloc/PostListBloc, but currently defaults
    // to the post passed in the constructor.
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Likes listener: ONLY update boolean (icon). Counts must come from PostActionsBloc.
        BlocListener<LikesBloc, LikesState>(
          listenWhen: (prev, curr) {
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
                'PostCard received LikeUpdated for post: ${_currentPost.id}. Updating boolean only.',
              );
              setState(() {
                _currentPost = _currentPost.copyWith(isLiked: state.isLiked);
                // DO NOT touch likesCount here — PostActionsBloc is authoritative for counts.
              });
            } else if (state is LikeError &&
                state.postId == _currentPost.id &&
                state.shouldRevert) {
              AppLogger.info(
                'PostCard received LikeError for post: ${_currentPost.id}. Reverting boolean only.',
              );
              setState(() {
                _currentPost = _currentPost.copyWith(
                  isLiked: state.previousState,
                );
                // DO NOT touch likesCount here; PostActionsBloc should handle reverting counts centrally.
              });
            }
          },
        ),

        // Favorites listener: ONLY update boolean. Counts come from PostActionsBloc.
        BlocListener<FavoritesBloc, FavoritesState>(
          listenWhen: (prev, curr) {
            if (curr is FavoriteUpdated && curr.postId == _currentPost.id) {
              return true;
            }
            if (curr is FavoriteError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is FavoriteUpdated && state.postId == _currentPost.id) {
              setState(() {
                _currentPost = _currentPost.copyWith(
                  isFavorited: state.isFavorited,
                );
                // DO NOT mutate favoritesCount here.
              });
            } else if (state is FavoriteError &&
                state.postId == _currentPost.id &&
                state.shouldRevert) {
              setState(() {
                _currentPost = _currentPost.copyWith(
                  isFavorited: state.previousState,
                );
                // DO NOT mutate favoritesCount here.
              });
            }
          },
        ),

        // Listener for the central optimistic update (counts/booleans)
        BlocListener<PostActionsBloc, PostActionsState>(
          listenWhen: (prev, curr) =>
              curr is PostOptimisticallyUpdated &&
              curr.post.id == _currentPost.id,
          listener: (context, state) {
            if (state is PostOptimisticallyUpdated) {
              AppLogger.info(
                'PostCard received PostOptimisticallyUpdated for post: ${state.post.id}. Updating post.',
              );
              setState(() {
                // Update the local PostEntity with the one carrying the new counts/booleans
                _currentPost = state.post;
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
    );
  }
}
