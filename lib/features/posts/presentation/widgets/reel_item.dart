import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
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
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                      'ReelItem received LikeUpdated for ${_currentPost.id}',
                    );
                    setState(() {
                      _currentPost = _currentPost.copyWith(
                        isLiked: state.isLiked,
                      );
                    });
                  } else if (state is LikeError &&
                      state.postId == _currentPost.id &&
                      state.shouldRevert) {
                    AppLogger.info(
                      'ReelItem received LikeError for ${_currentPost.id} — reverting icon',
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
                  if (curr is FavoriteUpdated && curr.postId == _currentPost.id)
                    return true;
                  if (curr is FavoriteError &&
                      curr.postId == _currentPost.id &&
                      curr.shouldRevert)
                    return true;
                  return false;
                },
                listener: (context, state) {
                  if (state is FavoriteUpdated &&
                      state.postId == _currentPost.id) {
                    AppLogger.info(
                      'ReelItem received FavoriteUpdated for ${_currentPost.id}',
                    );
                    setState(() {
                      _currentPost = _currentPost.copyWith(
                        isFavorited: state.isFavorited,
                      );
                    });
                  } else if (state is FavoriteError &&
                      state.postId == _currentPost.id &&
                      state.shouldRevert) {
                    AppLogger.info(
                      'ReelItem received FavoriteError for ${_currentPost.id} — reverting icon',
                    );
                    setState(() {
                      _currentPost = _currentPost.copyWith(
                        isFavorited: state.previousState,
                      );
                    });
                  }
                },
              ),
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: Colors.white),
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                  ),
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
