import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/theme/app_theme.dart';
import 'package:vlone_blog_app/core/presentation/widgets/load_more_error_reel.dart';
import 'package:vlone_blog_app/core/presentation/widgets/end_of_reels_indicator.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reels/reel_item.dart';
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
  late PageController _pageController;
  int _currentPage = 0;
  bool _isPageChanging = false;
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

    final currentState = context.read<ReelsBloc>().state;

    // Determining if we can load more from the BLoC state
    List<PostEntity> currentPosts = context.read<ReelsBloc>().getPostsFromState(
      currentState,
    );
    bool hasMoreReels = false;

    if (currentState is ReelsLoaded) {
      hasMoreReels = currentState.hasMore;
    } else if (currentState is ReelsLoadingMore ||
        currentState is ReelsLoadMoreError) {
      hasMoreReels = true;
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

  Future<void> _onRefresh(String userId) async {
    final completer = Completer<void>();
    context.read<ReelsBloc>().add(
      RefreshReelsEvent(userId, refreshCompleter: completer),
    );
    return completer.future;
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

  bool _hasExistingPosts(ReelsState state) {
    return _getPostsFromState(state).isNotEmpty;
  }

  List<PostEntity> _getPostsFromState(ReelsState state) {
    if (state is ReelsLoaded) {
      return state.posts;
    } else if (state is ReelsLoadingMore) {
      return state.posts;
    } else if (state is ReelsLoadMoreError) {
      return state.posts;
    } else if (state is ReelsError) {
      return state.posts;
    }
    return [];
  }

  void _showRefreshErrorSnackbar(BuildContext context, String message) {
    SnackbarUtils.showError(
      context,
      'Refresh failed: $message',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => _onRefresh(context.read<AuthBloc>().cachedUser!.id),
      ),
      durationSeconds: 4,
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
            BlocListener<ReelsBloc, ReelsState>(
              listener: (context, state) {
                // 1. Handle Refresh Completer Completion
                final completer = (state is ReelsLoaded)
                    ? state.refreshCompleter
                    : (state is ReelsError)
                    ? state.refreshCompleter
                    : null;
                completer?.complete();

                // 2. Manage _isLoadingMore flag
                if (mounted &&
                    _isLoadingMore &&
                    (state is ReelsLoaded || state is ReelsLoadMoreError)) {
                  setState(() => _isLoadingMore = false);
                }

                // 3. Fallback check
                if (state is ReelsLoaded) {
                  _ensureRealtimeActive(state);
                }

                // 4. Show snackbar for refresh errors when we have existing posts
                if (state is ReelsError && _hasExistingPosts(state)) {
                  _showRefreshErrorSnackbar(context, state.message);
                }
              },
            ),
          ],
          child: RefreshIndicator(
            backgroundColor: Colors.black,
            color: Colors.white,
            onRefresh: () => _onRefresh(currentUserId),
            child: Builder(
              builder: (context) {
                final reelsState = context.watch<ReelsBloc>().state;

                if (reelsState is ReelsLoading || reelsState is ReelsInitial) {
                  return const Center(child: LoadingIndicator(size: 32));
                }

                // All these states contain a list of posts or are an error state.
                if (reelsState is ReelsLoaded ||
                    reelsState is ReelsLoadingMore ||
                    reelsState is ReelsLoadMoreError ||
                    reelsState is ReelsError) {
                  // Extract data using the public BLoC method
                  final List<PostEntity> posts = _getPostsFromState(reelsState);

                  // Check if the list is completely empty for the full error widget
                  if (reelsState is ReelsError && posts.isEmpty) {
                    return CustomErrorWidget(
                      message: reelsState.message,
                      onRetry: () => _onRefresh(currentUserId),
                    );
                  }

                  final bool hasMoreReels = (reelsState is ReelsLoaded)
                      ? reelsState.hasMore
                      : (reelsState is ReelsLoadMoreError ||
                            reelsState is ReelsLoadingMore)
                      ? true // Always allow loading/retry if not fully loaded
                      : false;

                  final bool isLoadMoreError = reelsState is ReelsLoadMoreError;

                  if (posts.isEmpty && reelsState is! ReelsLoadingMore) {
                    return EmptyStateWidget(
                      message: 'No reels yet',
                      icon: Icons.video_library_outlined,
                      actionText: 'Refresh',
                      onRetry: () => _onRefresh(currentUserId),
                    );
                  }

                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount:
                        posts.length +
                        (hasMoreReels ? 1 : 0) +
                        (posts.isNotEmpty && !hasMoreReels ? 1 : 0),
                    onPageChanged: _onPageChanged,
                    physics: const PageScrollPhysics(),
                    itemBuilder: (context, index) {
                      // Show end of reels indicator
                      if (!hasMoreReels &&
                          index == posts.length &&
                          posts.isNotEmpty) {
                        return EndOfReelsIndicator(
                          message: "You've reached the end",
                          icon: Icons.flag_outlined,
                          iconSize: 48.0,
                          spacing: 16.0,
                        );
                      }

                      // Show loading more or error reel
                      if (hasMoreReels && index == posts.length) {
                        if (isLoadMoreError) {
                          return LoadMoreErrorReel(
                            message: reelsState.message,
                            onRetry: () {
                              if (!_isLoadingMore) {
                                setState(() => _isLoadingMore = true);
                                context.read<ReelsBloc>().add(
                                  const LoadMoreReelsEvent(),
                                );
                              }
                            },
                          );
                        } else {
                          return _buildLoadingReel();
                        }
                      }

                      // Get the post *directly from the BLoC's list*
                      final post = posts[index];
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
