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

import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';

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
  String? _userId;
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);
  final List<PostEntity> _posts = [];
  bool _hasMore = true;
  bool _isRealtimeActive = false;
  bool _hasLoadedOnce = false;
  String? _loadMoreError;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      _userId = _extractUserId(authState);
      if (_userId != null && mounted) {
        setState(() {});
        context.read<NotificationsBloc>().add(
          NotificationsSubscribeUnreadCountStream(),
        );
        // 💡 Ensure StartFeedRealtime is dispatched here if it's not handled by MainPage
        context.read<FeedBloc>().add(const StartFeedRealtime());
      } else if (mounted) {
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
        Debouncer.instance.debounce('load_more_feed', _loadMoreDebounce, () {
          if (!_hasMore) return;
          if (_isLoadingMore) return;
          if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200) {
            AppLogger.info(
              'FeedPage: near bottom; dispatching LoadMoreFeedEvent',
            );
            _isLoadingMore = true;
            context.read<FeedBloc>().add(const LoadMoreFeedEvent());
          }
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    final authState = context.read<AuthBloc>().state;
    final userId = _extractUserId(authState);
    if (userId != null) {
      context.read<FeedBloc>().add(RefreshFeedEvent(userId));
    }
  }

  /// Smart merging strategy: (Logic remains the same)
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

    // Fallback: conservative replacement
    setState(() {
      _posts
        ..clear()
        ..addAll(newPosts); // Rely on the full list from the BLoC
    });
  }

  @override
  void dispose() {
    // 💡 Ensure StopFeedRealtime is dispatched
    context.read<FeedBloc>().add(const StopFeedRealtime());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_userId == null) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
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
          BlocListener<FeedBloc, FeedState>(
            listener: (context, state) {
              // 1. Core Data Update: Handles list replacement, load more, and all realtime changes
              if (state is FeedLoaded) {
                // The BLoC handles the merging and internal updates (realtime, optimistic)
                _updatePosts(state.posts);
                _hasMore = state.hasMore;
                _isRealtimeActive = state.isRealtimeActive;
                _hasLoadedOnce = true;
                _loadMoreError = null;
                _isLoadingMore = false; // clear guard for any successful fetch
              }
              // 2. Loading State Management
              else if (state is FeedLoadingMore) {
                _isLoadingMore = true;
              }
              // 3. Error State Management
              else if (state is FeedLoadMoreError) {
                if (mounted) {
                  _loadMoreError = state.message;
                  _isLoadingMore = false;
                }
              } else if (state is FeedError) {
                // General error, handled by the Builder below
                _isLoadingMore = false;
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: Builder(
            builder: (context) {
              final feedState = context.watch<FeedBloc>().state;

              if (feedState is FeedLoading || feedState is FeedInitial) {
                return const Center(child: LoadingIndicator());
              }
              if (feedState is FeedError) {
                return CustomErrorWidget(
                  message: feedState.message,
                  onRetry: _onRefresh,
                );
              }

              // Only rely on local state (_hasLoadedOnce) and posts list
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
                    context.read<FeedBloc>().add(const LoadMoreFeedEvent());
                  },
                  controller: _scrollController,
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
