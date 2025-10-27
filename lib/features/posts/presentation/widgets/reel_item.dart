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
    // Accept external updates (e.g., server real-time)
    if (widget.post != oldWidget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Stack(
      fit: StackFit.expand,
      children: [
        ReelVideoPlayer(
          post: _currentPost,
          isActive: widget.isActive,
          shouldPreload: widget.isPrevious || widget.isNext,
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: MultiBlocListener(
            listeners: [
              // IMPORTANT: do NOT apply counts here. PostsBloc is authoritative for counts.
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
                    // Only update boolean (icon), counts come from PostsBloc parent
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
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child:
                              _currentPost.content != null &&
                                  _currentPost.content!.isNotEmpty
                              ? Text(
                                  _currentPost.content!,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.3,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black87,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      const SizedBox(width: 12),

                      SizedBox(
                        width: 50,
                        child: ReelActions(
                          post: _currentPost,
                          userId: widget.userId,
                        ),
                      ),
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
