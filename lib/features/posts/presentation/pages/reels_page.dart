import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_item.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class ReelsPage extends StatefulWidget {
  final bool isVisible;
  final String userId;

  const ReelsPage({super.key, this.isVisible = true, required this.userId});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final List<PostEntity> _posts = [];
  bool _realtimeStarted = false;
  bool _hasLoadedOnce = false;
  late PageController _pageController;
  int _currentPage = 0;
  bool _isPageChanging = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing ReelsPage for user: ${widget.userId}');
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);

    WidgetsBinding.instance.addObserver(this);

    // <-- REMOVED: All logic trying to get user from AuthBloc
  }

  @override
  void didUpdateWidget(ReelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      AppLogger.info('ReelsPage visibility changed: ${widget.isVisible}');
      if (!widget.isVisible) {
        VideoPlaybackManager.pause();
      } else if (widget.isVisible && _posts.isNotEmpty) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AppLogger.info('App lifecycle paused/inactive - pausing reel video');
      VideoPlaybackManager.pause();
    }
  }

  void _startRealtimeListeners() {
    if (!_realtimeStarted && mounted) {
      AppLogger.info('Starting real-time listeners from ReelsPage');
      context.read<PostsBloc>().add(StartRealtimeListenersEvent(widget.userId));
      _realtimeStarted = true;
    }
  }

  void _stopRealtimeListeners() {
    if (_realtimeStarted && mounted) {
      AppLogger.info('Stopping real-time listeners from ReelsPage');
      context.read<PostsBloc>().add(StopRealtimeListenersEvent());
      _realtimeStarted = false;
    }
  }

  void _updatePosts(List<PostEntity> newPosts) {
    final oldIds = _posts.map((p) => p.id).toList();
    final newIds = newPosts.map((p) => p.id).toList();

    if (oldIds.length == newIds.length &&
        oldIds.every((id) => newIds.contains(id))) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < newPosts.length; i++) {
          _posts[i] = newPosts[i];
        }
      });
    } else {
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(newPosts);
      });

      if (_posts.isNotEmpty && _pageController.hasClients) {
        _pageController.jumpToPage(0);
        _currentPage = 0;
      }
    }
  }

  void _onPageChanged(int index) {
    if (_isPageChanging) return;

    setState(() {
      _currentPage = index;
      _isPageChanging = true;
    });

    AppLogger.info('Reel page changed to index: $index');

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isPageChanging = false);
      }
    });
  }

  void _applyPostUpdate(
    String postId, {
    int? likesDelta,
    bool? isLiked,
    int? favoritesDelta,
    bool? isFavorited,
  }) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) return;

    final old = _posts[index];
    final updated = old.copyWith(
      likesCount:
          (likesDelta != null ? (old.likesCount + likesDelta) : old.likesCount)
              .clamp(0, double.infinity)
              .toInt(),
      isLiked: isLiked ?? old.isLiked,
      favoritesCount:
          (favoritesDelta != null
                  ? (old.favoritesCount + favoritesDelta)
                  : old.favoritesCount)
              .clamp(0, double.infinity)
              .toInt(),
      isFavorited: isFavorited ?? old.isFavorited,
    );
    setState(() => _posts[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is ReelsLoaded) {
                AppLogger.info(
                  'Reels loaded with ${state.posts.length} posts for user: ${widget.userId}',
                );
                if (mounted) {
                  _updatePosts(state.posts);
                  _hasLoadedOnce = true;

                  if (!_realtimeStarted && !state.isRealtimeActive) {
                    _startRealtimeListeners();
                  }
                }
              } else if (state is PostCreated &&
                  state.post.mediaType == 'video') {
                AppLogger.info('New video post created: ${state.post.id}');
              } else if (state is RealtimePostUpdate) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  final post = _posts[index];
                  final updatedPost = post.copyWith(
                    likesCount: (state.likesCount ?? post.likesCount)
                        .clamp(0, double.infinity)
                        .toInt(),
                    commentsCount: (state.commentsCount ?? post.commentsCount)
                        .clamp(0, double.infinity)
                        .toInt(),
                    favoritesCount:
                        (state.favoritesCount ?? post.favoritesCount)
                            .clamp(0, double.infinity)
                            .toInt(),
                    sharesCount: (state.sharesCount ?? post.sharesCount)
                        .clamp(0, double.infinity)
                        .toInt(),
                  );
                  setState(() => _posts[index] = updatedPost);
                }
              } else if (state is PostDeleted) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  setState(() => _posts.removeAt(index));
                }
              } else if (state is PostsError) {
                AppLogger.error('PostsError in ReelsPage: ${state.message}');
              }
            },
          ),
          BlocListener<LikesBloc, LikesState>(
            listener: (context, state) {
              if (state is LikeUpdated) {
                final delta = state.isLiked ? 1 : -1;
                _applyPostUpdate(
                  state.postId,
                  likesDelta: delta,
                  isLiked: state.isLiked,
                );
              } else if (state is LikeError) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  final old = _posts[index];
                  setState(
                    () => _posts[index] = old.copyWith(
                      isLiked: state.previousState,
                    ),
                  );
                  final correctedCount = state.previousState
                      ? (old.likesCount + 1)
                      : (old.likesCount - 1);
                  setState(
                    () => _posts[index] = _posts[index].copyWith(
                      likesCount: correctedCount
                          .clamp(0, double.infinity)
                          .toInt(),
                    ),
                  );
                }
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteUpdated) {
                final delta = state.isFavorited ? 1 : -1;
                _applyPostUpdate(
                  state.postId,
                  favoritesDelta: delta,
                  isFavorited: state.isFavorited,
                );
              } else if (state is FavoriteError) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  final old = _posts[index];
                  setState(
                    () => _posts[index] = old.copyWith(
                      isFavorited: state.previousState,
                    ),
                  );
                  final correctedCount = state.previousState
                      ? (old.favoritesCount + 1)
                      : (old.favoritesCount - 1);
                  setState(
                    () => _posts[index] = _posts[index].copyWith(
                      favoritesCount: correctedCount
                          .clamp(0, double.infinity)
                          .toInt(),
                    ),
                  );
                }
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing reels for user: ${widget.userId}');

            _stopRealtimeListeners();

            final bloc = context.read<PostsBloc>();
            bloc.add(GetReelsEvent(widget.userId));

            await bloc.stream.firstWhere(
              (state) => state is ReelsLoaded || state is PostsError,
            );

            _startRealtimeListeners();
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;

              if (_hasLoadedOnce) {
                if (_posts.isEmpty) {
                  return EmptyStateWidget(
                    message: 'No reels yet. Create a video post!',
                    icon: Icons.video_library,
                    actionText: 'Check Again',
                    onRetry: () => context.read<PostsBloc>().add(
                      GetReelsEvent(widget.userId),
                    ),
                  );
                }

                return PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _posts.length,
                  onPageChanged: _onPageChanged,
                  physics: const PageScrollPhysics(),
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final isCurrentPage = index == _currentPage;

                    return ReelItem(
                      key: ValueKey(post.id),
                      post: post,
                      userId: widget.userId,
                      isActive: isCurrentPage && widget.isVisible,
                      isPrevious: index == _currentPage - 1,
                      isNext: index == _currentPage + 1,
                    );
                  },
                );
              }

              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const LoadingIndicator();
              }

              if (postsState is PostsError) {
                return CustomErrorWidget(
                  message: postsState.message,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetReelsEvent(widget.userId),
                  ),
                );
              }

              return const LoadingIndicator();
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing ReelsPage');
    WidgetsBinding.instance.removeObserver(this);
    VideoPlaybackManager.pause();
    _pageController.dispose();
    _stopRealtimeListeners();
    super.dispose();
  }
}
