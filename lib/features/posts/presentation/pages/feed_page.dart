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

  void _updatePosts(List<PostEntity> newPosts) {
    if (!mounted) return;

    if (_posts.isNotEmpty &&
        newPosts.isNotEmpty &&
        _posts.length == newPosts.length &&
        listEquals(
          _posts.map((p) => p.id).toList(),
          newPosts.map((p) => p.id).toList(),
        )) {
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

    if (newIds.length >= oldIds.length &&
        listEquals(newIds.sublist(0, oldIds.length), oldIds)) {
      final tail = newPosts.sublist(oldIds.length);
      setState(() {
        for (int i = 0; i < oldIds.length; i++) {
          if (_posts[i] != newPosts[i]) _posts[i] = newPosts[i];
        }
        if (tail.isNotEmpty) _posts.addAll(tail);
      });
      return;
    }

    if (newIds.length >= oldIds.length &&
        listEquals(newIds.sublist(newIds.length - oldIds.length), oldIds)) {
      final headLength = newIds.length - oldIds.length;
      final head = newPosts.sublist(0, headLength);
      setState(() {
        if (head.isNotEmpty) _posts.insertAll(0, head);
        for (int i = 0; i < oldIds.length; i++) {
          final newIndex = headLength + i;
          if (_posts[newIndex] != newPosts[newIndex])
            _posts[newIndex] = newPosts[newIndex];
        }
      });
      return;
    }

    setState(() {
      _posts
        ..clear()
        ..addAll(newPosts);
    });
  }

  @override
  void dispose() {
    context.read<FeedBloc>().add(const StopFeedRealtime());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_userId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingIndicator(size: 32),
              const SizedBox(height: 16),
              Text(
                'Loading your feed...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const UserGreetingTitle(),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
        actions: [const NotificationIconWithBadge()],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<FeedBloc, FeedState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                _updatePosts(state.posts);
                _hasMore = state.hasMore;
                _isRealtimeActive = state.isRealtimeActive;
                _hasLoadedOnce = true;
                _loadMoreError = null;
                _isLoadingMore = false;
              } else if (state is FeedLoadingMore) {
                _isLoadingMore = true;
              } else if (state is FeedLoadMoreError) {
                if (mounted) {
                  _loadMoreError = state.message;
                  _isLoadingMore = false;
                }
              } else if (state is FeedError) {
                _isLoadingMore = false;
              }
            },
          ),
        ],
        child: RefreshIndicator(
          backgroundColor: Theme.of(context).colorScheme.background,
          color: Theme.of(context).colorScheme.primary,
          onRefresh: _onRefresh,
          child: Builder(
            builder: (context) {
              final feedState = context.watch<FeedBloc>().state;

              if (feedState is FeedLoading || feedState is FeedInitial) {
                return const Center(child: LoadingIndicator(size: 32));
              }
              if (feedState is FeedError) {
                return CustomErrorWidget(
                  message: feedState.message,
                  onRetry: _onRefresh,
                );
              }

              if (_hasLoadedOnce) {
                if (_posts.isEmpty) {
                  return EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                    actionText: 'Create Post',
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}
