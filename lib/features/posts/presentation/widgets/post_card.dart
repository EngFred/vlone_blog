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
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
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
              });
            }
          },
        ),
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
              });
            } else if (state is FavoriteError &&
                state.postId == _currentPost.id &&
                state.shouldRevert) {
              setState(() {
                _currentPost = _currentPost.copyWith(
                  isFavorited: state.previousState,
                );
              });
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
                'PostCard received PostOptimisticallyUpdated for post: ${state.post.id}. Updating post.',
              );
              setState(() {
                _currentPost = state.post;
              });
            }
          },
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: PhysicalModel(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostHeader(post: _currentPost, currentUserId: widget.userId),
                  if (_currentPost.content != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12,
                      ),
                      child: Text(
                        _currentPost.content!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  if (_currentPost.mediaUrl != null) const SizedBox(height: 4),
                  if (_currentPost.mediaUrl != null)
                    PostMedia(post: _currentPost, height: _kMediaDefaultHeight),
                  const SizedBox(height: 12),
                  PostActions(post: _currentPost, userId: widget.userId),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
