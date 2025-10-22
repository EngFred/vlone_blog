import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    // REMOVED: No auto-load here. MainPage dispatches GetReelsEvent when tab selected.
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
            // FIX: Only log errors silently for interactions; no toasts
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
