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
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

class ReelsPage extends StatefulWidget {
  final bool isVisible;
  const ReelsPage({super.key, this.isVisible = true});
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
    AppLogger.info('Initializing ReelsPage');
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthBloc>().cachedUser?.id;
      if (userId != null) {
        context.read<PostsBloc>().add(GetReelsEvent(userId));
        _startRealtimeListeners(userId);
      } else {
        AppLogger.warning(
          'ReelsPage: userId null at init; waiting for AuthBloc',
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReelsPage oldWidget) {
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

  void _startRealtimeListeners(String userId) {
    if (!_realtimeStarted && mounted) {
      AppLogger.info(
        'Starting real-time listeners from ReelsPage for user $userId',
      );
      context.read<PostsBloc>().add(StartRealtimeListenersEvent(userId));
      context.read<LikesBloc>().add(StartLikesStreamEvent(userId));
      context.read<FavoritesBloc>().add(StartFavoritesStreamEvent(userId));
      _realtimeStarted = true;
    }
  }

  void _stopRealtimeListeners() {
    if (_realtimeStarted && mounted) {
      AppLogger.info('Stopping real-time listeners from ReelsPage');
      context.read<PostsBloc>().add(StopRealtimeListenersEvent());
      context.read<LikesBloc>().add(StopLikesStreamEvent());
      context.read<FavoritesBloc>().add(StopFavoritesStreamEvent());
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
      if (mounted) setState(() => _isPageChanging = false);
    });
  }

  void _applyPostUpdate(String postId, {bool? isLiked, bool? isFavorited}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) return;
    final old = _posts[index];
    final updated = old.copyWith(
      isLiked: isLiked ?? old.isLiked,
      isFavorited: isFavorited ?? old.isFavorited,
    );
    setState(() => _posts[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is ReelsLoaded) {
                AppLogger.info(
                  'Reels loaded with ${state.posts.length} posts for user: $currentUserId',
                );
                if (mounted) {
                  _updatePosts(state.posts);
                  _hasLoadedOnce = true;
                  if (!_realtimeStarted && !state.isRealtimeActive) {
                    _startRealtimeListeners(currentUserId);
                  }
                }
              } else if (state is PostCreated &&
                  state.post.mediaType == 'video') {
                final exists = _posts.any((p) => p.id == state.post.id);
                if (!exists && mounted) {
                  setState(() => _posts.insert(0, state.post));
                }
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
              }
            },
          ),
          BlocListener<LikesBloc, LikesState>(
            listener: (context, state) {
              if (state is LikeSuccess) {
                // Optimistic update
                _applyPostUpdate(state.postId, isLiked: state.isLiked);
              } else if (state is LikeUpdated) {
                // Real-time update (eventual consistency)
                _applyPostUpdate(state.postId, isLiked: state.isLiked);
              } else if (state is LikeError) {
                AppLogger.error('Like error in ReelsPage: ${state.message}');
                // Revert optimistic update on failure
                if (state.shouldRevert) {
                  _applyPostUpdate(state.postId, isLiked: state.previousState);
                  // if (mounted) {
                  //   SnackbarUtils.showError(
                  //     context,
                  //     'Failed to ${state.previousState ? 'unlike' : 'like'} reel.',
                  //   );
                  // }
                }
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteSuccess) {
                // Optimistic update
                _applyPostUpdate(state.postId, isFavorited: state.isFavorited);
              } else if (state is FavoriteUpdated) {
                // Real-time update (eventual consistency)
                _applyPostUpdate(state.postId, isFavorited: state.isFavorited);
              } else if (state is FavoriteError) {
                AppLogger.error(
                  'Favorite error in ReelsPage: ${state.message}',
                );
                // Revert optimistic update on failure
                if (state.shouldRevert) {
                  _applyPostUpdate(
                    state.postId,
                    isFavorited: state.previousState,
                  );
                  // if (mounted) {
                  //   SnackbarUtils.showError(
                  //     context,
                  //     'Failed to ${state.previousState ? 'unfavorite' : 'favorite'} reel.',
                  //   );
                  // }
                }
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing reels for user: $currentUserId');
            _stopRealtimeListeners();
            final bloc = context.read<PostsBloc>();
            bloc.add(GetReelsEvent(currentUserId));
            await bloc.stream.firstWhere(
              (state) => state is ReelsLoaded || state is PostsError,
            );
            _startRealtimeListeners(currentUserId);
          },
          child: Builder(
            builder: (context) {
              if (_hasLoadedOnce) {
                if (_posts.isEmpty) {
                  return EmptyStateWidget(
                    message: 'No reels yet. Create a video post!',
                    icon: Icons.video_library,
                    actionText: 'Check Again',
                    onRetry: () => context.read<PostsBloc>().add(
                      GetReelsEvent(currentUserId),
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
                      userId: currentUserId,
                      isActive: isCurrentPage && widget.isVisible,
                      isPrevious: index == _currentPage - 1,
                      isNext: index == _currentPage + 1,
                    );
                  },
                );
              }
              final postsState = context.watch<PostsBloc>().state;
              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const LoadingIndicator();
              }
              if (postsState is PostsError) {
                return CustomErrorWidget(
                  message: postsState.message,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetReelsEvent(currentUserId),
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
