import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:vlone_blog_app/features/posts/presentation/widgets/post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<PostEntity> _posts = [];
  String? _userId;
  final _client = sl<SupabaseClient>();

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
            // fetch interaction states once we have user and posts
            _fetchInteractionStates();
          } else {
            AppLogger.info('Fetching initial feed for user: $_userId');
            context.read<PostsBloc>().add(GetFeedEvent());
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

  Future<void> _fetchInteractionStates() async {
    if (_userId == null || _posts.isEmpty) return;
    final postIds = _posts.map((p) => p.id).toList();
    try {
      final likesResponse = await _client
          .from('likes')
          .select('post_id')
          .inFilter('post_id', postIds)
          .eq('user_id', _userId!);
      final likedIds = <String>{};
      for (final like in likesResponse) likedIds.add(like['post_id'] as String);

      final favoritesResponse = await _client
          .from('favorites')
          .select('post_id')
          .inFilter('post_id', postIds)
          .eq('user_id', _userId!);
      final favoritedIds = <String>{};
      for (final fav in favoritesResponse)
        favoritedIds.add(fav['post_id'] as String);

      if (mounted) {
        setState(() {
          for (int i = 0; i < _posts.length; i++) {
            final post = _posts[i];
            _posts[i] = post.copyWith(
              isLiked: likedIds.contains(post.id),
              isFavorited: favoritedIds.contains(post.id),
            );
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching interaction states: $e', error: e);
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
                  _fetchInteractionStates();
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
            if (mounted) {
              setState(() => _posts.clear());
            }
            context.read<PostsBloc>().add(GetFeedEvent());
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
                  onRetry: () => context.read<PostsBloc>().add(GetFeedEvent()),
                  actionText: 'Retry',
                );
              } else if (_posts.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No posts yet. Create one to get started!',
                  icon: Icons.post_add,
                );
              }

              return ListView.builder(
                key: const PageStorageKey('feed_list'),
                cacheExtent: 1500.0,
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return PostCard(
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
