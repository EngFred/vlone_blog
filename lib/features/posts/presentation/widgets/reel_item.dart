import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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
    // Prevents stomping on optimistic updates if a refresh happens.
    if (widget.post != oldWidget.post && widget.post.id == oldWidget.post.id) {
      _currentPost = widget.post;
    } else if (widget.post.id != oldWidget.post.id) {
      // Different post entirely
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Define a custom theme data for the header and text overlay
    // that uses white text/icons for maximum contrast over video.
    final lightContrastTheme = Theme.of(context).copyWith(
      // Force all icons to be white
      iconTheme: const IconThemeData(color: Colors.white),
      // Force all text to be white
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      // *** FIX: Explicitly set ListTile colors to white ***
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
      // Crucially, force the DialogTheme to be light. This ensures the
      // dialog spawned from PostHeader will use light colors for its
      // text content, preventing the "white-on-white" issue you observed
      // if the app was in dark theme but the dialog used a white content color.
      dialogTheme: Theme.of(context).dialogTheme.copyWith(
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black),
        contentTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      // Force the overall color scheme to be "light" for widget behaviors
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: Colors.black, // Ensure dialog text is dark
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
        ),

        // Enhanced gradient overlay
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

        // Top gradient
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
              // --- MODIFIED: LikesBloc Listener ---
              BlocListener<LikesBloc, LikesState>(
                listenWhen: (prev, curr) {
                  // ONLY care about errors for reverting...
                  if (curr is LikeError &&
                      curr.postId == _currentPost.id &&
                      curr.shouldRevert) {
                    return true;
                  }
                  // ...or realtime updates (delta == 0) for syncing
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
                    // This is a REALTIME SYNC
                    AppLogger.info(
                      'ReelItem received REALTIME LikeUpdated for ${_currentPost.id}. Syncing boolean.',
                    );
                    context.read<PostActionsBloc>().add(
                      OptimisticPostUpdate(
                        post: _currentPost,
                        deltaLikes: 0,
                        deltaFavorites: 0,
                        isLiked: state.isLiked, // Sync the boolean
                      ),
                    );
                  } else if (state is LikeError) {
                    // This is a FAILED optimistic update. We must REVERT.
                    AppLogger.info(
                      'ReelItem received LikeError for ${_currentPost.id} — reverting count & boolean.',
                    );
                    // Dispatch a "revert" event to PostActionsBloc
                    context.read<PostActionsBloc>().add(
                      OptimisticPostUpdate(
                        post: _currentPost, // Pass the *current* post
                        deltaLikes: -state.delta, // Apply the *opposite* delta
                        deltaFavorites: 0,
                        isLiked: state.previousState, // Revert boolean
                      ),
                    );
                  }
                },
              ),
              // --- MODIFIED: FavoritesBloc Listener ---
              BlocListener<FavoritesBloc, FavoritesState>(
                listenWhen: (prev, curr) {
                  // ONLY care about errors for reverting...
                  if (curr is FavoriteError &&
                      curr.postId == _currentPost.id &&
                      curr.shouldRevert) {
                    return true;
                  }
                  // ...or realtime updates (delta == 0) for syncing
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
                    // This is a REALTIME SYNC
                    AppLogger.info(
                      'ReelItem received REALTIME FavoriteUpdated for ${_currentPost.id}. Syncing boolean.',
                    );
                    context.read<PostActionsBloc>().add(
                      OptimisticPostUpdate(
                        post: _currentPost,
                        deltaLikes: 0,
                        deltaFavorites: 0,
                        isFavorited: state.isFavorited, // Sync boolean
                      ),
                    );
                  } else if (state is FavoriteError) {
                    // This is a FAILED optimistic update. We must REVERT.
                    AppLogger.info(
                      'ReelItem received FavoriteError for ${_currentPost.id} — reverting count & boolean.',
                    );
                    // Dispatch a "revert" event to PostActionsBloc
                    context.read<PostActionsBloc>().add(
                      OptimisticPostUpdate(
                        post: _currentPost, // Pass the *current* post
                        deltaLikes: 0,
                        deltaFavorites: -state.delta, // Apply *opposite* delta
                        isFavorited: state.previousState, // Revert boolean
                      ),
                    );
                  }
                },
              ),
              // --- ADDED: PostActionsBloc Listener ---
              // This is now the SINGLE source of truth for updating _currentPost
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
                // Apply the lightContrastTheme to PostHeader and its descendants
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
                                    color: Colors
                                        .white, // Already white, but ensure
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
                            // Audio/song info (optional - you can add this if your posts have audio)
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
