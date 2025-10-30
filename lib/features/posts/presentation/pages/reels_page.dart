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
  bool _hasLoadedOnce = false;
  late PageController _pageController;
  int _currentPage = 0;
  bool _isPageChanging = false;
  bool _hasMoreReels = true; // Added: Track hasMore locally
  bool _isLoadingMore = false; // Added: Prevent duplicate loads

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthBloc>().cachedUser?.id;
      if (userId != null) {
        // Removed: StartRealtimeListenersEvent and GetReelsEvent - handled by MainPage
      } else {
        AppLogger.warning(
          'FeedPage: userId null at init; waiting for AuthBloc',
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

  void _updatePosts(List<PostEntity> newPosts) {
    if (!mounted) return;
    final oldIds = _posts.map((p) => p.id).toSet();
    final newIds = newPosts.map((p) => p.id).toSet();
    if (oldIds.length == newIds.length && oldIds.containsAll(newIds)) {
      setState(() {
        for (int i = 0; i < newPosts.length; i++) {
          if (_posts[i] != newPosts[i]) _posts[i] = newPosts[i];
        }
      });
    } else {
      AppLogger.info(
        'Updating reels list. Old: ${oldIds.length}, New: ${newIds.length}',
      );
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

    // Added guard: don't attempt load-more until initial load completed
    if (!_hasLoadedOnce) return;

    // Added: Load more if near the end (preemptive, 2 pages before end)
    if (index >= _posts.length - 2 && _hasMoreReels && !_isLoadingMore) {
      final currentUserId = context.read<AuthBloc>().cachedUser?.id;
      if (currentUserId != null) {
        setState(() => _isLoadingMore = true);
        context.read<PostsBloc>().add(LoadMoreReelsEvent());
      }
    }
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
          // PostsBloc: authoritative updates (server)
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is ReelsLoaded) {
                AppLogger.info('Reels loaded with ${state.posts.length} posts');
                if (mounted) {
                  _updatePosts(state.posts);
                  _hasMoreReels = state.hasMore; // Added: Update hasMore
                  _hasLoadedOnce = true;
                  _isLoadingMore = false; // Added: Reset loading flag
                }
              } else if (state is PostCreated &&
                  state.post.mediaType == 'video') {
                final exists = _posts.any((p) => p.id == state.post.id);
                if (!exists && mounted)
                  setState(() => _posts.insert(0, state.post));
              } else if (state is RealtimePostUpdate) {
                // Server authoritative counts — overwrite the local post
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
                if (index != -1 && mounted)
                  setState(() => _posts.removeAt(index));
              } else if (state is ReelsLoadingMore) {
                // Optional: Handle loading more state if needed
              } else if (state is ReelsLoadMoreError) {
                AppLogger.error('Load more reels error: ${state.message}');
                if (mounted) setState(() => _isLoadingMore = false);
              }
            },
          ),
          // LikesBloc: only handle server confirmations or errors (do NOT apply optimistic deltas at page level).
          BlocListener<LikesBloc, LikesState>(
            listener: (context, state) {
              if (state is LikeSuccess) {
                final idx = _posts.indexWhere((p) => p.id == state.postId);
                if (idx != -1 && mounted) {
                  final old = _posts[idx];
                  final updated = old.copyWith(isLiked: state.isLiked);
                  setState(() => _posts[idx] = updated);
                }
              } else if (state is LikeError && state.shouldRevert) {
                AppLogger.error('Like error in ReelsPage: ${state.message}');
                final idx = _posts.indexWhere((p) => p.id == state.postId);
                if (idx != -1 && mounted) {
                  final old = _posts[idx];
                  final revertedCount = (old.likesCount - state.delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  final updated = old.copyWith(
                    isLiked: state.previousState,
                    likesCount: revertedCount,
                  );
                  setState(() => _posts[idx] = updated);
                }
                // Revert central optimistic update so all pages remain consistent
                context.read<PostsBloc>().add(
                  OptimisticPostUpdate(
                    postId: state.postId,
                    deltaLikes: -state.delta,
                    deltaFavorites: 0,
                    isLiked: state.previousState,
                    isFavorited: null,
                  ),
                );
              }
            },
          ),
          // FavoritesBloc: same approach as likes — do NOT apply optimistic deltas at page level
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteSuccess) {
                final idx = _posts.indexWhere((p) => p.id == state.postId);
                if (idx != -1 && mounted) {
                  final old = _posts[idx];
                  final updated = old.copyWith(isFavorited: state.isFavorited);
                  setState(() => _posts[idx] = updated);
                }
              } else if (state is FavoriteError && state.shouldRevert) {
                AppLogger.error(
                  'Favorite error in ReelsPage: ${state.message}',
                );
                final idx = _posts.indexWhere((p) => p.id == state.postId);
                if (idx != -1 && mounted) {
                  final old = _posts[idx];
                  final revertedCount = (old.favoritesCount - state.delta)
                      .clamp(0, double.infinity)
                      .toInt();
                  final updated = old.copyWith(
                    isFavorited: state.previousState,
                    favoritesCount: revertedCount,
                  );
                  setState(() => _posts[idx] = updated);
                }
                // Revert central optimistic update so all pages remain consistent
                context.read<PostsBloc>().add(
                  OptimisticPostUpdate(
                    postId: state.postId,
                    deltaLikes: 0,
                    deltaFavorites: -state.delta,
                    isLiked: null,
                    isFavorited: state.previousState,
                  ),
                );
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing reels for user: $currentUserId');
            final bloc = context.read<PostsBloc>();
            bloc.add(
              RefreshReelsEvent(currentUserId),
            ); // Changed to RefreshReelsEvent for consistency
            await bloc.stream.firstWhere(
              (state) => state is ReelsLoaded || state is PostsError,
            );
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
                  itemCount:
                      _posts.length +
                      (_hasMoreReels
                          ? 1
                          : 0), // Extra for loading footer if hasMore
                  onPageChanged: _onPageChanged,
                  physics: const PageScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (_hasMoreReels && index == _posts.length) {
                      // Defensive: if we somehow hit loading footer before initial load, show loading
                      return const Center(child: LoadingIndicator());
                    }
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
              if (postsState is PostsLoading || postsState is PostsInitial)
                return const LoadingIndicator();
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
    super.dispose();
  }
}
