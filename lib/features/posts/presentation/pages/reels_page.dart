import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/theme/app_theme.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_item.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});
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
  bool _hasMoreReels = true;
  bool _isLoadingMore = false;
  bool _isPageVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
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

    final shouldJumpToStart =
        newIds.isNotEmpty && !oldIds.contains(newIds.first);

    AppLogger.info(
      'Updating reels list. Old: ${oldIds.length}, New: ${newIds.length}',
    );
    setState(() {
      _posts
        ..clear()
        ..addAll(newPosts);
    });

    if (_posts.isNotEmpty && _pageController.hasClients && shouldJumpToStart) {
      _pageController.jumpToPage(0);
      _currentPage = 0;
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

    if (!_hasLoadedOnce) return;

    if (index >= _posts.length - 2 && _hasMoreReels && !_isLoadingMore) {
      final currentUserId = context.read<AuthBloc>().cachedUser?.id;
      if (currentUserId != null) {
        setState(() => _isLoadingMore = true);
        context.read<ReelsBloc>().add(const LoadMoreReelsEvent());
      }
    }
  }

  Widget _buildLoadingReel() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const LoadingIndicator(size: 24),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingIndicator(size: 32),
              const SizedBox(height: 16),
              Text(
                'Loading reels...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: VisibilityDetector(
        key: const Key('reels_page_visibility'),
        onVisibilityChanged: (VisibilityInfo info) {
          final visibleFraction = info.visibleFraction;

          if (visibleFraction == 0 && _isPageVisible) {
            AppLogger.info(
              'ReelsPage hidden - pausing video and restoring status bar',
            );
            VideoPlaybackManager.pause();
            setState(() => _isPageVisible = false);
            // Restore default status bar when leaving the page (e.g., changing tabs)
            AppTheme.restoreDefaultStatusBar(context);
          } else if (visibleFraction > 0 && !_isPageVisible) {
            AppLogger.info(
              'ReelsPage visible - resuming video and setting status bar',
            );
            setState(() => _isPageVisible = true);
            // Re-apply Reels status bar style when returning to the page
            AppTheme.setStatusBarForReels();
          }
        },
        child: MultiBlocListener(
          listeners: [
            BlocListener<ReelsBloc, ReelsState>(
              listener: (context, state) {
                if (state is ReelsLoaded) {
                  AppLogger.info(
                    'Reels loaded with ${state.posts.length} posts',
                  );
                  if (mounted) {
                    _updatePosts(state.posts);
                    _hasMoreReels = state.hasMore;
                    _hasLoadedOnce = true;
                    _isLoadingMore = false;
                  }
                } else if (state is ReelsLoadMoreError) {
                  AppLogger.error('Load more reels error: ${state.message}');
                  if (mounted) setState(() => _isLoadingMore = false);
                }
              },
            ),
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
                  context.read<ReelsBloc>().add(
                    UpdateReelsPostOptimistic(
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
            BlocListener<FavoritesBloc, FavoritesState>(
              listener: (context, state) {
                if (state is FavoriteSuccess) {
                  final idx = _posts.indexWhere((p) => p.id == state.postId);
                  if (idx != -1 && mounted) {
                    final old = _posts[idx];
                    final updated = old.copyWith(
                      isFavorited: state.isFavorited,
                    );
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
                  context.read<ReelsBloc>().add(
                    UpdateReelsPostOptimistic(
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
            backgroundColor: Colors.black,
            color: Colors.white,
            onRefresh: () async {
              AppLogger.info('Refreshing reels for user: $currentUserId');
              final bloc = context.read<ReelsBloc>();
              bloc.add(RefreshReelsEvent(currentUserId));
              await bloc.stream.firstWhere(
                (state) => state is ReelsLoaded || state is ReelsError,
              );
            },
            child: Builder(
              builder: (context) {
                final reelsState = context.watch<ReelsBloc>().state;

                if (_hasLoadedOnce) {
                  if (_posts.isEmpty) {
                    return EmptyStateWidget(
                      message: 'No reels yet',
                      icon: Icons.video_library_outlined,
                      actionText: 'Refresh',
                      onRetry: () => context.read<ReelsBloc>().add(
                        GetReelsEvent(currentUserId),
                      ),
                    );
                  }
                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _posts.length + (_hasMoreReels ? 1 : 0),
                    onPageChanged: _onPageChanged,
                    physics: const PageScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (_hasMoreReels && index == _posts.length) {
                        return _buildLoadingReel();
                      }
                      final post = _posts[index];
                      final isCurrentPage = index == _currentPage;
                      return ReelItem(
                        key: ValueKey(post.id),
                        post: post,
                        userId: currentUserId,
                        isActive: isCurrentPage && _isPageVisible,
                        isPrevious: index == _currentPage - 1,
                        isNext: index == _currentPage + 1,
                      );
                    },
                  );
                }

                if (reelsState is ReelsLoading || reelsState is ReelsInitial)
                  return const Center(child: LoadingIndicator(size: 32));
                if (reelsState is ReelsError) {
                  return CustomErrorWidget(
                    message: reelsState.message,
                    onRetry: () => context.read<ReelsBloc>().add(
                      GetReelsEvent(currentUserId),
                    ),
                  );
                }
                return const Center(child: LoadingIndicator(size: 32));
              },
            ),
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
    // Removed: StopReelsRealtime() — now managed by MainPage

    // Status bar restoration is handled by VisibilityDetector when the page becomes invisible.
    // Explicitly calling restore here is often too late or unnecessary.

    super.dispose();
  }
}
