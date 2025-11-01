import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_header.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_video_player.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_actions.dart';

class ReelItem extends StatefulWidget {
  final PostEntity post;
  final String userId;
  final bool isActive;
  final bool isPrevious;
  final bool isNext;

  const ReelItem({
    super.key,
    required this.post,
    required this.userId,
    required this.isActive,
    this.isPrevious = false,
    this.isNext = false,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem>
    with AutomaticKeepAliveClientMixin {
  late PostEntity _currentPost;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same robustness check as PostCard:
    if (widget.post != oldWidget.post && widget.post.id == oldWidget.post.id) {
      _currentPost = widget.post;
    } else if (widget.post.id != oldWidget.post.id) {
      _currentPost = widget.post;
    }
  }

  // Called when the video widget detects a double-tap.
  // We now ensure double-tap only likes (never unlikes).
  void _handleDoubleTapLike() {
    final isLiked = _currentPost.isLiked;

    // NEW: If already liked, do NOT send an unlike. Just provide subtle feedback.
    if (isLiked) {
      HapticFeedback.lightImpact();
      AppLogger.info(
        'Double-tap detected but post already liked: ${_currentPost.id}',
      );
      return;
    }

    // Otherwise, proceed to like the post (optimistic update + bloc event)
    context.read<LikesBloc>().add(
      LikePostEvent(
        postId: _currentPost.id,
        userId: widget.userId,
        isLiked: true, // explicitly like
        previousState: isLiked,
      ),
    );

    // Optimistically update post counts locally via PostActionsBloc
    const int delta = 1;
    context.read<PostActionsBloc>().add(
      OptimisticPostUpdate(
        post: _currentPost,
        deltaLikes: delta,
        deltaFavorites: 0,
        isLiked: true,
        isFavorited: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final lightContrastTheme = Theme.of(context).copyWith(
      iconTheme: const IconThemeData(color: Colors.white),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
      dialogTheme: Theme.of(context).dialogTheme.copyWith(
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black),
        contentTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black54,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ReelVideoPlayer(
          post: _currentPost,
          isActive: widget.isActive,
          shouldPreload: widget.isPrevious || widget.isNext,
          onDoubleTap:
              _handleDoubleTapLike, // <<-- Hook double-tap to like (no second debounce)
        ),

        // Gradients and overlays...
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),

        SafeArea(
          child: MultiBlocListener(
            listeners: [
              // LikesBloc listener (unchanged logic)
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
                      'ReelItem received REALTIME LikeUpdated for ${_currentPost.id}. Syncing boolean.',
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
                      'ReelItem received LikeError for ${_currentPost.id} — reverting count & boolean.',
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

              // FavoritesBloc listener (unchanged logic)
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
                      'ReelItem received REALTIME FavoriteUpdated for ${_currentPost.id}. Syncing boolean.',
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
                      'ReelItem received FavoriteError for ${_currentPost.id} — reverting count & boolean.',
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

              // PostActionsBloc sync (single source of truth)
              BlocListener<PostActionsBloc, PostActionsState>(
                listenWhen: (prev, curr) =>
                    curr is PostOptimisticallyUpdated &&
                    curr.post.id == _currentPost.id,
                listener: (context, state) {
                  if (state is PostOptimisticallyUpdated) {
                    AppLogger.info(
                      'ReelItem (PostActionsBloc) received PostOptimisticallyUpdated for post: ${state.post.id}. Updating state.',
                    );
                    setState(() {
                      _currentPost = state.post;
                    });
                  }
                },
              ),
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Theme(
                  data: lightContrastTheme,
                  child: PostHeader(
                    post: _currentPost,
                    currentUserId: widget.userId,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_currentPost.content != null &&
                                _currentPost.content!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _currentPost.content!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 12,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.music_note,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Original Sound',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ReelActions(post: _currentPost, userId: widget.userId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
