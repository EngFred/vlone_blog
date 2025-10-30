import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed_list.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/notification_icon_with_badge.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/user_greeting_title.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String? _userId; // Store userId from AuthBloc
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);
  final List<PostEntity> _posts = []; // Added: Local posts list
  bool _hasMore = true; // Added: Local hasMore
  bool _isRealtimeActive = false; // Added: Local realtime status
  bool _hasLoadedOnce = false; // Added: To track initial load
  String? _loadMoreError; // Added: For load more errors

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      _userId = _extractUserId(
        authState,
      ); // Helper to extract without maybeWhen
      if (_userId != null && mounted) {
        setState(() {}); // Trigger rebuild to pass userId
        // Removed: GetFeedEvent and StartRealtimeListenersEvent - handled by MainPage
        context.read<NotificationsBloc>().add(
          NotificationsSubscribeUnreadCountStream(),
        );
      } else if (mounted) {
        // Handle unauthenticated: e.g., redirect or show login
        AppLogger.warning('User not authenticated in FeedPage');
      }
    });
  }

  String? _extractUserId(AuthState state) {
    if (state is AuthAuthenticated) return state.user.id;
    return null;
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        // Debounce the load-more check on scroll (resets timer each time)
        Debouncer.instance.debounce('load_more_feed', _loadMoreDebounce, () {
          if (_hasMore &&
              _scrollController.position.pixels >=
                  _scrollController.position.maxScrollExtent - 200) {
            // NEW: log when we dispatch load-more for easier debugging
            AppLogger.info(
              'FeedPage: near bottom; dispatching LoadMoreFeedEvent',
            );
            context.read<PostsBloc>().add(const LoadMoreFeedEvent());
          }
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    final authState = context.read<AuthBloc>().state;
    final userId = _extractUserId(authState);
    if (userId != null) {
      context.read<PostsBloc>().add(RefreshFeedEvent(userId));
    }
  }

  void _updatePosts(List<PostEntity> newPosts) {
    if (!mounted) return;
    final oldIds = _posts.map((p) => p.id).toSet();
    final newIds = newPosts.map((p) => p.id).toSet();
    if (oldIds.length == newIds.length && oldIds.containsAll(newIds)) {
      setState(() {
        for (int i = 0; i < newPosts.length; i++) {
          if (_posts[i] != newPosts[i]) _posts[i] = newPosts[i];
        }
      });
    } else {
      AppLogger.info(
        'Updating feed list. Old: ${oldIds.length}, New: ${newIds.length}',
      );
      setState(() {
        _posts
          ..clear()
          ..addAll(newPosts);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For keepAlive
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      ); // Wait for userId
    }

    return Scaffold(
      appBar: AppBar(
        title: const UserGreetingTitle(),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [const NotificationIconWithBadge()],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                _updatePosts(state.posts);
                _hasMore = state.hasMore;
                _isRealtimeActive = state.isRealtimeActive;
                _hasLoadedOnce = true;
                _loadMoreError = null;
              } else if (state is PostCreated) {
                if (!mounted) return;
                final exists = _posts.any((p) => p.id == state.post.id);
                if (!exists) {
                  setState(() => _posts.insert(0, state.post));
                }
              } else if (state is RealtimePostUpdate) {
                if (!mounted) return;
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1) {
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
                if (!mounted) return;
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1) {
                  setState(() => _posts.removeAt(index));
                }
              } else if (state is FeedLoadMoreError) {
                if (mounted) {
                  _loadMoreError = state.message;
                }
              } else if (state is PostsError) {
                // Handle general error if needed
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: Builder(
            builder: (context) {
              final postsState = context.watch<PostsBloc>().state;
              if (postsState is PostsLoading || postsState is PostsInitial) {
                return const Center(child: LoadingIndicator());
              }
              if (postsState is PostsError) {
                return CustomErrorWidget(
                  message: postsState.message,
                  onRetry: _onRefresh,
                );
              }
              if (_hasLoadedOnce) {
                if (_posts.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                  );
                }
                return FeedList(
                  posts: _posts,
                  userId: _userId!,
                  hasMore: _hasMore,
                  isRealtimeActive: _isRealtimeActive,
                  loadMoreError: _loadMoreError,
                  onLoadMore: () =>
                      context.read<PostsBloc>().add(const LoadMoreFeedEvent()),
                  controller: _scrollController, // PASS IT
                );
              }
              return const Center(child: LoadingIndicator());
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
}
