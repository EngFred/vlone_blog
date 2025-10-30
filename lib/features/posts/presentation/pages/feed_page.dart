import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // Local guard to avoid dispatching multiple load-more events while one is in-flight
  bool _isLoadingMore = false;

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
          if (!_hasMore) return;
          if (_isLoadingMore) return; // prevent duplicate dispatches
          if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200) {
            // NEW: log when we dispatch load-more for easier debugging
            AppLogger.info(
              'FeedPage: near bottom; dispatching LoadMoreFeedEvent',
            );
            _isLoadingMore = true; // set guard until state tells us otherwise
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

  /// Smart merging strategy:
  /// - If local list is empty -> replace
  /// - If newPosts contains old posts as a prefix -> append only the tail (common case for load-more)
  /// - If newPosts contains old posts as a suffix -> prepend only the head (common for realtime new posts)
  /// - Otherwise do a conservative replacement while preserving overlapping ids where possible.
  void _updatePosts(List<PostEntity> newPosts) {
    if (!mounted) return;

    // Fast path: nothing to do
    if (_posts.isNotEmpty &&
        newPosts.isNotEmpty &&
        _posts.length == newPosts.length &&
        listEquals(
          _posts.map((p) => p.id).toList(),
          newPosts.map((p) => p.id).toList(),
        )) {
      // Same IDs in same order; update items in place to preserve scroll offset
      setState(() {
        for (int i = 0; i < newPosts.length; i++) {
          if (_posts[i] != newPosts[i]) _posts[i] = newPosts[i];
        }
      });
      return;
    }

    if (_posts.isEmpty) {
      setState(() {
        _posts.addAll(newPosts);
      });
      return;
    }

    final oldIds = _posts.map((p) => p.id).toList();
    final newIds = newPosts.map((p) => p.id).toList();

    // Case A: server returned [old..., tail...] -> append tail
    if (newIds.length >= oldIds.length &&
        listEquals(newIds.sublist(0, oldIds.length), oldIds)) {
      final tail = newPosts.sublist(oldIds.length);
      // update any changed existing items, then add tail
      setState(() {
        for (int i = 0; i < oldIds.length; i++) {
          if (_posts[i] != newPosts[i]) _posts[i] = newPosts[i];
        }
        if (tail.isNotEmpty) _posts.addAll(tail);
      });
      return;
    }

    // Case B: server returned [head..., old...] -> prepend head
    if (newIds.length >= oldIds.length &&
        listEquals(newIds.sublist(newIds.length - oldIds.length), oldIds)) {
      final headLength = newIds.length - oldIds.length;
      final head = newPosts.sublist(0, headLength);
      setState(() {
        // Insert head at front and update existing trailing items
        if (head.isNotEmpty) _posts.insertAll(0, head);
        for (int i = 0; i < oldIds.length; i++) {
          final newIndex = headLength + i;
          if (_posts[newIndex] != newPosts[newIndex])
            _posts[newIndex] = newPosts[newIndex];
        }
      });
      return;
    }

    // Fallback: produce merged list that prefers server order but doesn't throw away overlap
    final merged = <PostEntity>[];
    for (final np in newPosts) {
      final idx = _posts.indexWhere((e) => e.id == np.id);
      if (idx != -1) {
        // prefer server-provided entity (it contains freshest data)
        merged.add(np);
      } else {
        // new item: add it
        merged.add(np);
      }
    }

    setState(() {
      _posts
        ..clear()
        ..addAll(merged);
    });
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
              // Keep local loading flag in sync: PostsBloc emits FeedLoadingMore & FeedLoaded
              if (state is FeedLoaded) {
                _updatePosts(state.posts);
                _hasMore = state.hasMore;
                _isRealtimeActive = state.isRealtimeActive;
                _hasLoadedOnce = true;
                _loadMoreError = null;
                _isLoadingMore = false; // clear guard
              } else if (state is FeedLoadingMore) {
                _isLoadingMore = true;
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
                  _isLoadingMore = false;
                }
              } else if (state is PostsError) {
                // Handle general error if needed
                _isLoadingMore = false;
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
                  onLoadMore: () {
                    if (_isLoadingMore) return;
                    _isLoadingMore = true;
                    context.read<PostsBloc>().add(const LoadMoreFeedEvent());
                  },
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
