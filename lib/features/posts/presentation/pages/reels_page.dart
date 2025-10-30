import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
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
  bool _isPageVisible = true; // NEW: Local state to track page visibility

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
        // 💡 Dispatch StartReelsRealtime now that we are using the dedicated BLoC
        context.read<ReelsBloc>().add(const StartReelsRealtime());
      } else {
        AppLogger.warning(
          'ReelsPage: userId null at init; waiting for AuthBloc',
        );
      }
    });
  }

  // REMOVED: didUpdateWidget (no longer needed for isVisible prop)

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

    // Simple update logic: replace all for now, but preserve position if possible
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

    // ⚠️ CHANGE 2: Dispatch LoadMoreReelsEvent to ReelsBloc
    if (index >= _posts.length - 2 && _hasMoreReels && !_isLoadingMore) {
      final currentUserId = context.read<AuthBloc>().cachedUser?.id;
      if (currentUserId != null) {
        setState(() => _isLoadingMore = true);
        context.read<ReelsBloc>().add(const LoadMoreReelsEvent());
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
      body: VisibilityDetector(
        // NEW: Wrap body to detect visibility changes
        key: const Key('reels_page_visibility'),
        onVisibilityChanged: (VisibilityInfo info) {
          final visibleFraction = info.visibleFraction;
          if (visibleFraction == 0 && _isPageVisible) {
            AppLogger.info('ReelsPage hidden - pausing video');
            VideoPlaybackManager.pause();
            setState(() => _isPageVisible = false);
          } else if (visibleFraction > 0 && !_isPageVisible) {
            AppLogger.info('ReelsPage visible - resuming video');
            setState(
              () => _isPageVisible = true,
            ); // Triggers rebuild to resume current reel
          }
        },
        child: MultiBlocListener(
          listeners: [
            // ⚠️ CHANGE 3: Listen to ReelsBloc and ReelsState
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
                }
                // ⚠️ REMOVED: PostCreated/RealtimePostUpdate/PostDeleted handling
                // This is now handled internally by ReelsBloc and results in a ReelsLoaded state.
                else if (state is ReelsLoadMoreError) {
                  AppLogger.error('Load more reels error: ${state.message}');
                  if (mounted) setState(() => _isLoadingMore = false);
                }
                // ReelsLoadingMore/ReelsLoading/ReelsInitial are primarily used for UI checks in the Builder/Watcher
              },
            ),
            // LikesBloc: Revert optimistic update on error
            BlocListener<LikesBloc, LikesState>(
              listener: (context, state) {
                if (state is LikeSuccess) {
                  final idx = _posts.indexWhere((p) => p.id == state.postId);
                  if (idx != -1 && mounted) {
                    final old = _posts[idx];
                    // The count is updated by the RealtimePostUpdate listener in ReelsBloc,
                    // so we only update the local `isLiked` state optimistically here.
                    final updated = old.copyWith(isLiked: state.isLiked);
                    setState(() => _posts[idx] = updated);
                  }
                } else if (state is LikeError && state.shouldRevert) {
                  AppLogger.error('Like error in ReelsPage: ${state.message}');
                  // Revert local list state based on delta
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

                  // ⚠️ CHANGE 4: Revert central optimistic update by dispatching to ReelsBloc
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
            // FavoritesBloc: Revert optimistic update on error
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
                  // Revert local list state based on delta
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

                  // ⚠️ CHANGE 5: Revert central optimistic update by dispatching to ReelsBloc
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
            onRefresh: () async {
              AppLogger.info('Refreshing reels for user: $currentUserId');
              // ⚠️ CHANGE 6: Use ReelsBloc
              final bloc = context.read<ReelsBloc>();
              bloc.add(RefreshReelsEvent(currentUserId));
              // ⚠️ CHANGE 7: Wait for ReelsLoaded or ReelsError
              await bloc.stream.firstWhere(
                (state) => state is ReelsLoaded || state is ReelsError,
              );
            },
            child: Builder(
              builder: (context) {
                // ⚠️ CHANGE 8: Watch ReelsBloc
                final reelsState = context.watch<ReelsBloc>().state;

                if (_hasLoadedOnce) {
                  if (_posts.isEmpty) {
                    return EmptyStateWidget(
                      message: 'No reels yet. Create a video post!',
                      icon: Icons.video_library,
                      actionText: 'Check Again',
                      // ⚠️ CHANGE 9: Use ReelsBloc and GetReelsEvent
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
                        return const Center(child: LoadingIndicator());
                      }
                      final post = _posts[index];
                      final isCurrentPage = index == _currentPage;
                      return ReelItem(
                        key: ValueKey(post.id),
                        post: post,
                        userId: currentUserId,
                        isActive:
                            isCurrentPage &&
                            _isPageVisible, // UPDATED: Use local _isPageVisible
                        isPrevious: index == _currentPage - 1,
                        isNext: index == _currentPage + 1,
                      );
                    },
                  );
                }

                // ⚠️ CHANGE 10: Use ReelsBloc states
                if (reelsState is ReelsLoading || reelsState is ReelsInitial)
                  return const LoadingIndicator();
                if (reelsState is ReelsError) {
                  return CustomErrorWidget(
                    message: reelsState.message,
                    // ⚠️ CHANGE 11: Use ReelsBloc and GetReelsEvent
                    onRetry: () => context.read<ReelsBloc>().add(
                      GetReelsEvent(currentUserId),
                    ),
                  );
                }
                return const LoadingIndicator();
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
    // 💡 Dispatch StopReelsRealtime
    context.read<ReelsBloc>().add(const StopReelsRealtime());
    super.dispose();
  }
}
