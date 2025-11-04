import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/theme/app_theme.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
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
  // --- REFACTORED STATE ---
  // All local state duplicating the BLoC is REMOVED.
  // -REMOVED: final List<PostEntity> _posts = [];
  // -REMOVED: bool _hasLoadedOnce = false;
  // -REMOVED: bool _hasMoreReels = true;
  // -REMOVED: bool _isRealtimeActive = false;

  late PageController _pageController;
  int _currentPage = 0;
  bool _isPageChanging = false;
  bool _isLoadingMore = false;
  bool _isPageVisible = true;
  // --- END REFACTORED STATE ---

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

  // --- REMOVED `_updatePosts` method ---
  // This complex logic is no longer needed. The BLoC state is the truth.

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

    // Get the *current* state directly from the BLoC
    final currentState = context.read<ReelsBloc>().state;

    // Determine if we can load more from the BLoC state
    List<PostEntity> currentPosts = [];
    bool hasMoreReels = false;

    if (currentState is ReelsLoaded) {
      currentPosts = currentState.posts;
      hasMoreReels = currentState.hasMore;
    } else if (currentState is ReelsLoadingMore) {
      currentPosts = currentState.posts;
      hasMoreReels = true; // Assume true if we're loading
    } else if (currentState is ReelsLoadMoreError) {
      currentPosts = currentState.posts;
      hasMoreReels = true; // Assume true to allow retry
    }

    if (index >= currentPosts.length - 2 && hasMoreReels && !_isLoadingMore) {
      final currentUserId = context.read<AuthBloc>().cachedUser?.id;
      if (currentUserId != null) {
        setState(() => _isLoadingMore = true);
        context.read<ReelsBloc>().add(const LoadMoreReelsEvent());
      }
    }
  }

  // Fallback mechanism
  void _ensureRealtimeActive(ReelsState state) {
    final currentUserId = context.read<AuthBloc>().cachedUser?.id;

    // Read realtime status *from the BLoC state*
    if (state is ReelsLoaded &&
        !state.isRealtimeActive &&
        currentUserId != null) {
      AppLogger.warning(
        'ReelsPage: Realtime was not active after load. Starting as fallback.',
      );
      context.read<ReelsBloc>().add(const StartReelsRealtime());
    }
  }

  Widget _buildLoadingReel() {
    // ... (This widget is fine, no changes needed)
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
      // ... (Initial loading widget is fine, no changes needed)
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
            AppTheme.restoreDefaultStatusBar(context);
          } else if (visibleFraction > 0 && !_isPageVisible) {
            AppLogger.info(
              'ReelsPage visible - resuming video and setting status bar',
            );
            setState(() => _isPageVisible = true);
            AppTheme.setStatusBarForReels();
          }
        },
        child: MultiBlocListener(
          listeners: [
            // This listener now only manages local UI state (_isLoadingMore)
            // and the realtime fallback.
            BlocListener<ReelsBloc, ReelsState>(
              listener: (context, state) {
                if (state is ReelsLoaded) {
                  AppLogger.info(
                    'Reels loaded with ${state.posts.length} posts',
                  );
                  if (mounted) {
                    setState(() {
                      _isLoadingMore = false;
                    });
                    _ensureRealtimeActive(state);
                  }
                } else if (state is ReelsLoadMoreError) {
                  AppLogger.error('Load more reels error: ${state.message}');
                  if (mounted) setState(() => _isLoadingMore = false);
                }
              },
            ),
            // --- REMOVED LikesBloc and FavoritesBloc Listeners ---
            // The BLoC state is now the single source of truth,
            // so manual state syncing is no longer needed.
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
                // --- SINGLE SOURCE OF TRUTH ---
                final reelsState = context.watch<ReelsBloc>().state;
                // --- END ---

                if (reelsState is ReelsLoading || reelsState is ReelsInitial) {
                  return const Center(child: LoadingIndicator(size: 32));
                }
                if (reelsState is ReelsError) {
                  return CustomErrorWidget(
                    message: reelsState.message,
                    onRetry: () => context.read<ReelsBloc>().add(
                      GetReelsEvent(currentUserId),
                    ),
                  );
                }

                // --- UNIFIED STATE HANDLING ---
                // All these states contain a list of posts.
                if (reelsState is ReelsLoaded ||
                    reelsState is ReelsLoadingMore ||
                    reelsState is ReelsLoadMoreError) {
                  // Extract data directly from the state
                  final List<PostEntity> posts = (reelsState as dynamic).posts;

                  final bool hasMoreReels = (reelsState is ReelsLoaded)
                      ? reelsState.hasMore
                      : true; // Always allow loading/retry

                  if (posts.isEmpty && reelsState is ReelsLoaded) {
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
                    itemCount: posts.length + (hasMoreReels ? 1 : 0),
                    onPageChanged: _onPageChanged,
                    physics: const PageScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (hasMoreReels && index == posts.length) {
                        return _buildLoadingReel();
                      }
                      // Get the post *directly from the BLoC's list*
                      final post = posts[index];
                      final isCurrentPage = index == _currentPage;

                      return ReelItem(
                        key: ValueKey(post.id),
                        post: post, // Pass the post from the BLoC state
                        userId: currentUserId,
                        isActive: isCurrentPage && _isPageVisible,
                        isPrevious: index == _currentPage - 1,
                        isNext: index == _currentPage + 1,
                      );
                    },
                  );
                }
                // --- END UNIFIED STATE HANDLING ---

                // Fallback
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
    super.dispose();
  }
}
