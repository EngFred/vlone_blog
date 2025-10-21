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
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<PostEntity> _posts = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FeedPage');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for FeedPage');
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
          // Only fetch feed if PostsBloc doesn't already have feed data
          final postsState = context.read<PostsBloc>().state;
          if (postsState is FeedLoaded && postsState.posts.isNotEmpty) {
            AppLogger.info('Using cached posts from PostsBloc');
            if (mounted) _updatePosts(postsState.posts);
          } else {
            AppLogger.info('Fetching initial feed for user: $_userId');
            context.read<PostsBloc>().add(GetFeedEvent(userId: _userId));
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
      appBar: AppBar(title: const Text('Feed')),
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                AppLogger.info(
                  'Feed loaded with ${state.posts.length} posts for user: $_userId',
                );
                if (mounted) {
                  _updatePosts(state.posts);
                }
              } else if (state is PostCreated) {
                AppLogger.info('New post created: ${state.post.id}');
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
                // no-op for now (optimistic updates handled in card)
              } else if (state is PostsError) {
                AppLogger.error('PostsError in FeedPage: ${state.message}');
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
            AppLogger.info('Refreshing feed for user: $_userId');
            // Not clearing posts here. Letting the BLoC state handle
            // updates. The indicator will spin automatically.
            final bloc = context.read<PostsBloc>();
            bloc.add(GetFeedEvent(userId: _userId));
            // Await the BLoC to finish loading or erroring
            // This ensures the RefreshIndicator spins correctly.
            await bloc.stream.firstWhere(
              (state) => state is FeedLoaded || state is PostsError,
            );
          },
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;

              // If we have posts, show them. This handles pull-to-refresh
              // gracefully, showing old data while new data loads.
              if (_posts.isNotEmpty) {
                return FeedList(posts: _posts, userId: _userId!);
              }

              // If _posts is empty, we decide what to show based on bloc state.

              // 1. Loading State
              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const LoadingIndicator();
              }

              // 2. Error State
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

              // 3. Loaded State
              if (postsState is FeedLoaded) {
                // The bloc loaded, and it loaded an empty list.
                if (postsState.posts.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                  );
                } else {
                  // This is the transient state!
                  // The bloc has posts, but our local _posts list hasn't
                  // updated yet. Show a loader for this frame.
                  return const LoadingIndicator();
                }
              }

              // Fallback for other states (e.g., PostCreated, etc.)
              // if _posts is still empty.
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
    super.dispose();
  }
}
