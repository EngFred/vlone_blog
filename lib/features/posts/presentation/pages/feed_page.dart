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
    _loadCurrentUserFromAuth();
  }

  void _loadCurrentUserFromAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userId = authState.user.id;
      AppLogger.info('Current user from AuthBloc: $_userId');
      _loadFeed();
    } else {
      AppLogger.error('No authenticated user, redirecting to login');
      context.go(Constants.loginRoute);
    }
  }

  void _loadFeed() {
    // Check for cached feed data
    final postsState = context.read<PostsBloc>().state;
    if (postsState is FeedLoaded && postsState.posts.isNotEmpty) {
      AppLogger.info('Using cached posts from PostsBloc');
      if (mounted) {
        _updatePosts(postsState.posts);
        if (!postsState.isRealtimeActive) {
          _startRealtimeListeners();
        } else {
          _realtimeStarted = true;
        }
      }
    } else {
      AppLogger.info('Fetching initial feed for user: $_userId');
      context.read<PostsBloc>().add(GetFeedEvent(userId: _userId));
    }
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
              final updatedPost = _posts[index].copyWith(
                likesCount: _posts[index].likesCount + (state.isLiked ? 1 : -1),
                isLiked: state.isLiked,
              );
              setState(() => _posts[index] = updatedPost);
            }
          } else if (state is PostFavorited) {
            final index = _posts.indexWhere((p) => p.id == state.postId);
            if (index != -1 && mounted) {
              final updatedPost = _posts[index].copyWith(
                favoritesCount:
                    _posts[index].favoritesCount + (state.isFavorited ? 1 : -1),
                isFavorited: state.isFavorited,
              );
              setState(() => _posts[index] = updatedPost);
            }
          } else if (state is RealtimePostUpdate) {
            final index = _posts.indexWhere((p) => p.id == state.postId);
            if (index != -1 && mounted) {
              final post = _posts[index];
              final updatedPost = post.copyWith(
                likesCount: state.likesCount ?? post.likesCount,
                commentsCount: state.commentsCount ?? post.commentsCount,
                favoritesCount: state.favoritesCount ?? post.favoritesCount,
                sharesCount: state.sharesCount ?? post.sharesCount,
              );
              setState(() => _posts[index] = updatedPost);
            }
          } else if (state is PostsError) {
            AppLogger.error('PostsError in FeedPage: ${state.message}');
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
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
