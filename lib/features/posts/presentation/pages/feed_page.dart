import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed_list.dart';

class FeedPage extends StatefulWidget {
  final String userId;
  const FeedPage({super.key, required this.userId});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  final List<PostEntity> _posts = [];
  bool _realtimeStarted = false;
  bool _hasLoadedOnce = false;

  // ✅ OPTIMIZATION: Keep page alive when switching tabs
  // This prevents rebuilding the entire feed when user navigates away and back
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FeedPage for user: ${widget.userId}');
  }

  void _startRealtimeListeners() {
    if (!_realtimeStarted && mounted) {
      AppLogger.info('Starting real-time listeners from FeedPage');
      context.read<PostsBloc>().add(StartRealtimeListenersEvent(widget.userId));
      _realtimeStarted = true;
    }
  }

  void _stopRealtimeListeners() {
    if (_realtimeStarted && mounted) {
      AppLogger.info('Stopping real-time listeners from FeedPage');
      context.read<PostsBloc>().add(StopRealtimeListenersEvent());
      _realtimeStarted = false;
    }
  }

  /// ✅ OPTIMIZED: Smart list update that minimizes rebuilds
  /// Only updates changed items instead of replacing entire list
  void _updatePosts(List<PostEntity> newPosts) {
    final oldIds = _posts.map((p) => p.id).toSet();
    final newIds = newPosts.map((p) => p.id).toSet();

    // ✅ PERFORMANCE: If same posts, only update modified ones
    if (oldIds.length == newIds.length && oldIds.containsAll(newIds)) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < newPosts.length; i++) {
          // Only update if content changed
          if (_posts[i] != newPosts[i]) {
            _posts[i] = newPosts[i];
          }
        }
      });
    } else {
      // Different posts - replace entire list
      if (!mounted) return;
      AppLogger.info(
        'Updating posts list. Old: ${oldIds.length}, New: ${newIds.length}',
      );
      setState(() {
        _posts
          ..clear()
          ..addAll(newPosts);
      });
    }
  }

  /// ✅ OPTIMIZED: Inline post updates without full list rebuild
  /// Updates counts directly in-place for better performance
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
    // ✅ CRITICAL: Call super.build for AutomaticKeepAliveClientMixin
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              context.push(Constants.notificationsRoute);
            },
          ),
          // ✅ Real-time indicator shows connection status
          if (_realtimeStarted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                AppLogger.info(
                  'Feed loaded with ${state.posts.length} posts for user: ${widget.userId}',
                );
                if (mounted) {
                  _updatePosts(state.posts);
                  _hasLoadedOnce = true;
                  // ✅ Start real-time listeners after initial load
                  if (!_realtimeStarted && !state.isRealtimeActive) {
                    _startRealtimeListeners();
                  }
                }
              } else if (state is PostCreated) {
                AppLogger.info(
                  'New post created (from PostCreated state): ${state.post.id}',
                );
                if (mounted) {
                  final exists = _posts.any((p) => p.id == state.post.id);
                  if (!exists) {
                    setState(() {
                      _posts.insert(0, state.post);
                    });
                  }
                  SnackbarUtils.showSuccess(
                    context,
                    'Post created successfully!',
                  );
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
              } else if (state is PostsError) {
                // ✅ OPTIMIZATION: Filter out non-critical errors to reduce snackbar spam
                if (!state.message.contains('update action') &&
                    !state.message.contains('like') &&
                    !state.message.contains('favorite') &&
                    !state.message.contains('share')) {
                  if (mounted) {
                    SnackbarUtils.showError(context, state.message);
                  }
                }
                AppLogger.error('PostsError in FeedPage: ${state.message}');
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
                if (state.shouldRevert) {
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
                SnackbarUtils.showError(context, state.message);
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
                if (state.shouldRevert) {
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
                SnackbarUtils.showError(context, state.message);
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing feed for user: ${widget.userId}');
            _stopRealtimeListeners();

            final bloc = context.read<PostsBloc>();
            bloc.add(GetFeedEvent(widget.userId));

            await bloc.stream.firstWhere(
              (state) => state is FeedLoaded || state is PostsError,
            );

            _startRealtimeListeners();
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;

              // ✅ OPTIMIZATION: Show cached posts immediately while loading
              if (_hasLoadedOnce) {
                if (_posts.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                  );
                }
                return FeedList(posts: _posts, userId: widget.userId);
              }

              // Initial load states
              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const LoadingIndicator();
              }

              if (postsState is PostsError) {
                return CustomErrorWidget(
                  message: postsState.message,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetFeedEvent(widget.userId),
                  ),
                );
              }

              return const LoadingIndicator();
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(
          Constants.createPostRoute.replaceAll(':userId', widget.userId),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing FeedPage');
    _stopRealtimeListeners();
    super.dispose();
  }
}
