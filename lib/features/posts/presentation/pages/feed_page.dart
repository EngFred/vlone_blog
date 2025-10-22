import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<PostEntity> _posts = [];
  String? _userId;
  bool _realtimeStarted = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FeedPage');
    // REMOVED: No auto-load here. MainPage dispatches GetFeedEvent when tab selected (initially for Feed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        setState(() => _userId = authState.user.id);
        AppLogger.info('Current user from AuthBloc: $_userId');
      }
    });
  }

  void _startRealtimeListeners() {
    if (!_realtimeStarted && _userId != null && mounted) {
      AppLogger.info('Starting real-time listeners from FeedPage');
      context.read<PostsBloc>().add(
        StartRealtimeListenersEvent(userId: _userId),
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const LoadingIndicator();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
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
      body: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is FeedLoaded) {
            AppLogger.info(
              'Feed loaded with ${state.posts.length} posts for user: $_userId',
            );
            if (mounted) {
              _updatePosts(state.posts);
              if (!_realtimeStarted && !state.isRealtimeActive) {
                _startRealtimeListeners();
              }
            }
          } else if (state is PostCreated) {
            AppLogger.info('New post created: ${state.post.id}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post created successfully!'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else if (state is PostLiked) {
            final index = _posts.indexWhere((p) => p.id == state.postId);
            if (index != -1 && mounted) {
              // FIX: Clamp to prevent negative counts
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
              // FIX: Clamp to prevent negative counts
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
              // FIX: Clamp to prevent negative counts from real-time updates
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
            // FIX: Only show errors for non-interaction failures (e.g., load/create). Log interaction errors silently.
            if (!state.message.contains('update action') &&
                !state.message.contains('like') &&
                !state.message.contains('favorite') &&
                !state.message.contains('share')) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              }
            }
            AppLogger.error('PostsError in FeedPage: ${state.message}');
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing feed for user: $_userId');

            // Stop real-time temporarily during refresh
            _stopRealtimeListeners();

            final bloc = context.read<PostsBloc>();
            bloc.add(GetFeedEvent(userId: _userId));

            // Await the BLoC to finish loading or erroring
            await bloc.stream.firstWhere(
              (state) => state is FeedLoaded || state is PostsError,
            );

            // Restart real-time after refresh
            _startRealtimeListeners();
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;

              // If we have posts, show them
              if (_posts.isNotEmpty) {
                return FeedList(posts: _posts, userId: _userId!);
              }

              // Loading State
              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const LoadingIndicator();
              }

              // Error State
              if (postsState is PostsError) {
                return EmptyStateWidget(
                  message: postsState.message,
                  icon: Icons.error_outline,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetFeedEvent(userId: _userId),
                  ),
                  actionText: 'Retry',
                );
              }

              // Loaded State
              if (postsState is FeedLoaded) {
                if (postsState.posts.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                  );
                } else {
                  // Transient state - loader while _posts updates
                  return const LoadingIndicator();
                }
              }

              return const LoadingIndicator();
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Constants.createPostRoute),
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
