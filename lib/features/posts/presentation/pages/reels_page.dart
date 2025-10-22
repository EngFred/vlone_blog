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
import 'package:vlone_blog_app/features/posts/presentation/widgets/reel_item.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final List<PostEntity> _posts = [];
  String? _userId;
  bool _realtimeStarted = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing ReelsPage');
    _loadCurrentUserFromAuth();
  }

  void _loadCurrentUserFromAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userId = authState.user.id;
      AppLogger.info('Current user from AuthBloc: $_userId');
      _loadReels();
    } else {
      AppLogger.error('No authenticated user, redirecting to login');
      context.go(Constants.loginRoute);
    }
  }

  void _loadReels() {
    final postsState = context.read<PostsBloc>().state;
    if (postsState is ReelsLoaded && postsState.posts.isNotEmpty) {
      AppLogger.info('Using cached reels from PostsBloc');
      if (mounted) {
        _updatePosts(postsState.posts);
        if (!postsState.isRealtimeActive) {
          _startRealtimeListeners();
        } else {
          _realtimeStarted = true;
        }
      }
    } else {
      AppLogger.info('Fetching initial reels for user: $_userId');
      context.read<PostsBloc>().add(GetReelsEvent(userId: _userId));
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (postsState is PostsLoading) {
                  return const LoadingIndicator();
                } else if (postsState is PostsError) {
                  return EmptyStateWidget(
                    message: postsState.message,
                    icon: Icons.error_outline,
                    onRetry: () => context.read<PostsBloc>().add(
                      GetReelsEvent(userId: _userId),
                    ),
                    actionText: 'Retry',
                  );
                } else {
                  return const EmptyStateWidget(
                    message: 'No reels yet. Create a video post!',
                    icon: Icons.video_library,
                  );
                }
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return ReelItem(
                    key: ValueKey(post.id),
                    post: post,
                    userId: _userId!,
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
    _stopRealtimeListeners();
    super.dispose();
  }
}
