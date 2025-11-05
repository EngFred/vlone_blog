import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/debounced_inkwell.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/comments_overlay.dart';

class PostActions extends StatefulWidget {
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

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  static const Duration _defaultDebounce = Duration(milliseconds: 500);
  static const double _kActionIconSize = 26.0;

  // This state holds the most current version of the post,
  // including optimistic updates.
  late PostEntity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  // This is crucial to sync the state if the parent list rebuilds
  // with new data (e.g., from a pull-to-refresh).
  @override
  void didUpdateWidget(covariant PostActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  void _share(BuildContext context) {
    context.read<PostActionsBloc>().add(SharePostEvent(_currentPost.id));
  }

  void _handleComment(BuildContext context) {
    if (widget.onCommentTap != null) {
      widget.onCommentTap!();
    } else {
      CommentsOverlay.show(context, _currentPost, widget.userId);
    }
  }

  Widget _buildActionItem({
    required Widget icon,
    String? count,
    required VoidCallback onTap,
    required String actionKey,
  }) {
    return DebouncedInkWell(
      actionKey: actionKey,
      duration: _defaultDebounce,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Text(count),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We now read counts from the local state `_currentPost`
    final baseLikesCount = _currentPost.likesCount;
    final baseFavoritesCount = _currentPost.favoritesCount;
    final baseCommentsCount = _currentPost.commentsCount;

    // This MultiBlocListener now lives here, localizing the rebuild.
    return MultiBlocListener(
      listeners: [
        // ==================== LIKE LISTENERS (Errors / Realtime) ====================
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
                'PostActions received REALTIME LikeUpdated for post: ${_currentPost.id}. Syncing boolean.',
              );
              // Dispatch to PostActionsBloc to get a new PostEntity
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
                'PostActions received LikeError for post: ${_currentPost.id}. Reverting count and boolean.',
              );
              // Dispatch to PostActionsBloc to get a new PostEntity
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
        // ==================== FAVORITE LISTENERS (Errors / Realtime) ====================
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
                'PostActions received REALTIME FavoriteUpdated for post: ${_currentPost.id}. Syncing boolean.',
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
                'PostActions received FavoriteError for post: ${_currentPost.id}. Reverting count and boolean.',
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
        // ==================== OPTIMISTIC UPDATE LISTENER ====================
        BlocListener<PostActionsBloc, PostActionsState>(
          listenWhen: (prev, curr) =>
              curr is PostOptimisticallyUpdated &&
              curr.post.id == _currentPost.id,
          listener: (context, state) {
            if (state is PostOptimisticallyUpdated) {
              AppLogger.info(
                'PostActions (PostActionsBloc) received PostOptimisticallyUpdated for post: ${state.post.id}. Updating local state.',
              );
              // This is the key: We call setState INSIDE PostActions
              setState(() {
                _currentPost = state.post;
              });
            }
          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // ==================== LIKE BUTTON ====================
                BlocBuilder<LikesBloc, LikesState>(
                  buildWhen: (prev, curr) {
                    // This buildWhen is still good, but we now also depend
                    // on the local _currentPost state for the count.
                    if (curr is LikesInitial) return true;
                    if (curr is LikeUpdated && curr.postId == _currentPost.id) {
                      return true;
                    }
                    if (curr is LikeError &&
                        curr.postId == _currentPost.id &&
                        curr.shouldRevert) {
                      return true;
                    }
                    return false;
                  },
                  builder: (context, state) {
                    // Use _currentPost.isLiked as the source of truth
                    bool isLiked = _currentPost.isLiked;

                    // The BlocBuilder *only* handles icon state
                    // in case the optimistic listener is slower.
                    if (state is LikeUpdated &&
                        state.postId == _currentPost.id) {
                      isLiked = state.isLiked;
                    } else if (state is LikeError &&
                        state.postId == _currentPost.id &&
                        state.shouldRevert) {
                      isLiked = state.previousState;
                    }

                    return _buildActionItem(
                      actionKey: 'like_${_currentPost.id}',
                      // Count comes from local state
                      count: baseLikesCount.toString(),
                      onTap: () {
                        context.read<LikesBloc>().add(
                          LikePostEvent(
                            postId: _currentPost.id,
                            userId: widget.userId,
                            isLiked: !isLiked,
                            previousState: isLiked,
                          ),
                        );

                        final int delta = (!isLiked) ? 1 : -1;
                        // We dispatch using _currentPost
                        context.read<PostActionsBloc>().add(
                          OptimisticPostUpdate(
                            post: _currentPost,
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
                const SizedBox(width: 16),
                // ==================== COMMENT BUTTON ====================
                _buildActionItem(
                  actionKey: 'comment_nav_${_currentPost.id}',
                  // Count comes from local state
                  count: widget.showCommentsCount
                      ? baseCommentsCount.toString()
                      : null,
                  onTap: () => _handleComment(context),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: _kActionIconSize,
                  ),
                ),
                const SizedBox(width: 16),
                // ==================== SHARE BUTTON ====================
                _buildActionItem(
                  actionKey: 'share_${_currentPost.id}',
                  count: 'Share',
                  onTap: () => _share(context),
                  icon: const Icon(Icons.send_outlined, size: _kActionIconSize),
                ),
              ],
            ),

            // ==================== FAVORITE BUTTON (BLOC) ====================
            BlocBuilder<FavoritesBloc, FavoritesState>(
              buildWhen: (prev, curr) {
                if (curr is FavoritesInitial) return true;
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
              builder: (context, state) {
                // Use _currentPost.isFavorited as the source of truth
                bool isFavorited = _currentPost.isFavorited;

                if (state is FavoriteUpdated &&
                    state.postId == _currentPost.id) {
                  isFavorited = state.isFavorited;
                } else if (state is FavoriteError &&
                    state.postId == _currentPost.id &&
                    state.shouldRevert) {
                  isFavorited = state.previousState;
                }

                return _buildActionItem(
                  actionKey: 'favorite_${_currentPost.id}',
                  // Count comes from local state
                  count: baseFavoritesCount.toString(),
                  onTap: () {
                    context.read<FavoritesBloc>().add(
                      FavoritePostEvent(
                        postId: _currentPost.id,
                        userId: widget.userId,
                        isFavorited: !isFavorited,
                        previousState: isFavorited,
                      ),
                    );

                    final int deltaFav = (!isFavorited) ? 1 : -1;
                    // We dispatch using _currentPost
                    context.read<PostActionsBloc>().add(
                      OptimisticPostUpdate(
                        post: _currentPost,
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
      ),
    );
  }
}
