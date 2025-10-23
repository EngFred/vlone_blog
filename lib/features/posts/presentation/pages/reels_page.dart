import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_item.dart';
import 'package:vlone_blog_app/features/posts/utils/video_playback_manager.dart';

class ReelsPage extends StatefulWidget {
  final bool isVisible; // Receive visibility state from MainPage

  const ReelsPage({super.key, this.isVisible = true});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final List<PostEntity> _posts = [];
  String? _userId;
  bool _realtimeStarted = false;
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

    // Listen to app lifecycle to pause videos when app goes background
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _userId = authState.user.id);
        AppLogger.info('Current user from AuthBloc: $_userId');
      }
    });
  }

  //Handle visibility changes from parent
  @override
  void didUpdateWidget(ReelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      AppLogger.info('ReelsPage visibility changed: ${widget.isVisible}');
      if (!widget.isVisible) {
        // Page became invisible - pause video
        VideoPlaybackManager.pause();
      } else if (widget.isVisible && _posts.isNotEmpty) {
        // Page became visible - trigger rebuild to resume current video
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
    if (!_realtimeStarted && _userId != null && mounted) {
      AppLogger.info('Starting real-time listeners from ReelsPage');
      context.read<PostsBloc>().add(
        StartRealtimeListenersEvent(userId: _userId),
      );
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

      // Reset to first page when posts change
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

    // Small delay to ensure smooth transition
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isPageChanging = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_userId == null) {
      return const LoadingIndicator();
    }

    return Scaffold(
      body: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is ReelsLoaded) {
            AppLogger.info(
              'Reels loaded with ${state.posts.length} posts for user: $_userId',
            );
            if (mounted) {
              _updatePosts(state.posts);

              if (!_realtimeStarted && !state.isRealtimeActive) {
                _startRealtimeListeners();
              }
            }
          } else if (state is PostCreated && state.post.mediaType == 'video') {
            AppLogger.info('New video post created: ${state.post.id}');
          } else if (state is PostLiked) {
            final index = _posts.indexWhere((p) => p.id == state.postId);
            if (index != -1 && mounted) {
              final delta = state.isLiked ? 1 : -1;
              final newCount = (_posts[index].likesCount + delta)
                  .clamp(0, double.infinity)
                  .toInt();
              final updatedPost = _posts[index].copyWith(
                likesCount: newCount,
                isLiked: state.isLiked,
              );
              setState(() => _posts[index] = updatedPost);
            }
          } else if (state is PostFavorited) {
            final index = _posts.indexWhere((p) => p.id == state.postId);
            if (index != -1 && mounted) {
              final delta = state.isFavorited ? 1 : -1;
              final newCount = (_posts[index].favoritesCount + delta)
                  .clamp(0, double.infinity)
                  .toInt();
              final updatedPost = _posts[index].copyWith(
                favoritesCount: newCount,
                isFavorited: state.isFavorited,
              );
              setState(() => _posts[index] = updatedPost);
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
                favoritesCount: (state.favoritesCount ?? post.favoritesCount)
                    .clamp(0, double.infinity)
                    .toInt(),
                sharesCount: (state.sharesCount ?? post.sharesCount)
                    .clamp(0, double.infinity)
                    .toInt(),
              );
              setState(() => _posts[index] = updatedPost);
            }
          } else if (state is PostsError) {
            AppLogger.error('PostsError in ReelsPage: ${state.message}');
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing reels for user: $_userId');

            _stopRealtimeListeners();

            final bloc = context.read<PostsBloc>();
            bloc.add(GetReelsEvent(userId: _userId));

            await bloc.stream.firstWhere(
              (state) => state is ReelsLoaded || state is PostsError,
            );

            _startRealtimeListeners();
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;

              if (_posts.isEmpty) {
                if (postsState is PostsLoading || postsState is PostsInitial) {
                  return const LoadingIndicator();
                } else if (postsState is PostsError) {
                  return CustomErrorWidget(
                    message: postsState.message,
                    onRetry: () => context.read<PostsBloc>().add(
                      GetReelsEvent(userId: _userId),
                    ),
                  );
                } else {
                  return EmptyStateWidget(
                    message: 'No reels yet. Create a video post!',
                    icon: Icons.video_library,
                    actionText: 'Check Again',
                    onRetry: () => context.read<PostsBloc>().add(
                      GetReelsEvent(userId: _userId),
                    ),
                  );
                }
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
                    userId: _userId!,
                    // Only active if current page AND parent page is visible
                    isActive: isCurrentPage && widget.isVisible,
                    isPrevious: index == _currentPage - 1,
                    isNext: index == _currentPage + 1,
                  );
                },
              );
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
