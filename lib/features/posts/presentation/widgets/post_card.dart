import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/expandable_text.dart';
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
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post && widget.post.id == oldWidget.post.id) {
      _currentPost = widget.post;
    } else if (widget.post.id != oldWidget.post.id) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LikesBloc, LikesState>(
          listenWhen: (prev, curr) {
            if (curr is LikeError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is LikeUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 &&
                curr.isLiked != _currentPost.isLiked) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is LikeUpdated) {
              AppLogger.info(
                'PostCard received REALTIME LikeUpdated for post: ${_currentPost.id}. Syncing boolean.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isLiked: state.isLiked,
                ),
              );
            } else if (state is LikeError) {
              AppLogger.info(
                'PostCard received LikeError for post: ${_currentPost.id}. Reverting count and boolean.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: -state.delta,
                  deltaFavorites: 0,
                  isLiked: state.previousState,
                ),
              );
            }
          },
        ),
        BlocListener<FavoritesBloc, FavoritesState>(
          listenWhen: (prev, curr) {
            if (curr is FavoriteError &&
                curr.postId == _currentPost.id &&
                curr.shouldRevert) {
              return true;
            }
            if (curr is FavoriteUpdated &&
                curr.postId == _currentPost.id &&
                curr.delta == 0 &&
                curr.isFavorited != _currentPost.isFavorited) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is FavoriteUpdated) {
              AppLogger.info(
                'PostCard received REALTIME FavoriteUpdated for post: ${_currentPost.id}. Syncing boolean.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: 0,
                  isFavorited: state.isFavorited,
                ),
              );
            } else if (state is FavoriteError) {
              AppLogger.info(
                'PostCard received FavoriteError for post: ${_currentPost.id}. Reverting count and boolean.',
              );
              context.read<PostActionsBloc>().add(
                OptimisticPostUpdate(
                  post: _currentPost,
                  deltaLikes: 0,
                  deltaFavorites: -state.delta,
                  isFavorited: state.previousState,
                ),
              );
            }
          },
        ),
        BlocListener<PostActionsBloc, PostActionsState>(
          listenWhen: (prev, curr) =>
              curr is PostOptimisticallyUpdated &&
              curr.post.id == _currentPost.id,
          listener: (context, state) {
            if (state is PostOptimisticallyUpdated) {
              AppLogger.info(
                'PostCard (PostActionsBloc) received PostOptimisticallyUpdated for post: ${state.post.id}. Updating state.',
              );
              setState(() {
                _currentPost = state.post;
              });
            }
          },
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostHeader(post: _currentPost, currentUserId: widget.userId),
            // --- NEW: Expandable / collapsible text for long text-only posts ---
            if (_currentPost.content != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: ExpandableText(
                  text: _currentPost.content!,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  collapsedMaxLines: 3, // Adjusted for Instagram-like brevity
                ),
              ),
            if (_currentPost.mediaUrl != null) const SizedBox(height: 4),
            if (_currentPost.mediaUrl != null) PostMedia(post: _currentPost),
            const SizedBox(height: 8),
            PostActions(post: _currentPost, userId: widget.userId),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
