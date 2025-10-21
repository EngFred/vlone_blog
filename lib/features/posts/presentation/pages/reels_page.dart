import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing ReelsPage');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for ReelsPage');
    try {
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          AppLogger.error('Failed to load current user: ${failure.message}');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
            context.go(Constants.loginRoute);
          }
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          if (mounted) setState(() => _userId = user.id);
          // Only fetch reels if PostsBloc doesn't already have reels data
          final postsState = context.read<PostsBloc>().state;
          if (postsState is ReelsLoaded && postsState.posts.isNotEmpty) {
            AppLogger.info('Using cached reels from PostsBloc');
            if (mounted) _updatePosts(postsState.posts);
          } else {
            AppLogger.info('Fetching initial reels for user: $_userId');
            context.read<PostsBloc>().add(GetReelsEvent(userId: _userId));
          }
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error loading user: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user: $e')));
        context.go(Constants.loginRoute);
      }
    }
  }

  // Update posts with a minimal change so widgets keep identity where possible.
  void _updatePosts(List<PostEntity> newPosts) {
    final oldIds = _posts.map((p) => p.id).toList();
    final newIds = newPosts.map((p) => p.id).toList();
    // If lists have same length and same ids, update in-place (keeps keys/widget state)
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is ReelsLoaded) {
                AppLogger.info(
                  'Reels loaded with ${state.posts.length} posts for user: $_userId',
                );
                if (mounted) {
                  _updatePosts(state.posts);
                }
              } else if (state is PostCreated &&
                  state.post.mediaType == 'video') {
                AppLogger.info('New video post created: ${state.post.id}');
                if (mounted) setState(() => _posts.insert(0, state.post));
              } else if (state is PostLiked) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  final updatedPost = _posts[index].copyWith(
                    likesCount:
                        _posts[index].likesCount + (state.isLiked ? 1 : -1),
                    isLiked: state.isLiked,
                  );
                  setState(() => _posts[index] = updatedPost);
                }
              } else if (state is PostShared) {
                // no-op for now (optimistic updates handled in actions)
              } else if (state is PostsError) {
                AppLogger.error('PostsError in ReelsPage: ${state.message}');
              }
            },
          ),
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteAdded) {
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
                  final updatedPost = _posts[index].copyWith(
                    favoritesCount:
                        _posts[index].favoritesCount +
                        (state.isFavorited ? 1 : -1),
                    isFavorited: state.isFavorited,
                  );
                  setState(() => _posts[index] = updatedPost);
                }
              } else if (state is FavoritesError) {
                // optionally show error
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing reels for user: $_userId');
            final bloc = context.read<PostsBloc>();
            bloc.add(GetReelsEvent(userId: _userId));
            await bloc.stream.firstWhere(
              (state) => state is ReelsLoaded || state is PostsError,
            );
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;
              if (postsState is PostsLoading && _posts.isEmpty) {
                return const LoadingIndicator();
              } else if (postsState is PostsError && _posts.isEmpty) {
                return EmptyStateWidget(
                  message: postsState.message,
                  icon: Icons.error_outline,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetReelsEvent(userId: _userId),
                  ),
                  actionText: 'Retry',
                );
              } else if (_posts.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No reels yet. Create a video post!',
                  icon: Icons.video_library,
                );
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
    super.dispose();
  }
}
