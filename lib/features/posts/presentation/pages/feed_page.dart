import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
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
  bool _notificationsSubscribed = false;
  static const Duration _loadMoreDebounce = Duration(milliseconds: 300);

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
        // Removed: _subscribeNotifications() - moved to MainPage
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
          final state = context.read<PostsBloc>().state;
          if (state is FeedLoaded &&
              state.hasMore &&
              _scrollController.position.pixels >=
                  _scrollController.position.maxScrollExtent - 200) {
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: BlocBuilder<PostsBloc, PostsState>(
          builder: (context, state) {
            if (state is PostsLoading || state is PostsInitial) {
              return const Center(child: LoadingIndicator());
            }
            if (state is FeedLoaded) {
              if (state.posts.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No posts yet. Create one to get started!',
                  icon: Icons.post_add,
                );
              }
              return FeedList(
                posts: state.posts,
                userId: _userId!, // Pass userId
                hasMore: state.hasMore,
                isRealtimeActive: state.isRealtimeActive,
                onLoadMore: () =>
                    context.read<PostsBloc>().add(const LoadMoreFeedEvent()),
              );
            }
            if (state is FeedLoadMoreError) {
              return FeedList(
                posts: state.currentPosts,
                userId: _userId!, // Pass userId
                hasMore: true,
                loadMoreError: state.message,
                onLoadMore: () =>
                    context.read<PostsBloc>().add(const LoadMoreFeedEvent()),
              );
            }
            if (state is PostsError) {
              return CustomErrorWidget(
                message: state.message,
                onRetry: _onRefresh,
              );
            }
            // Fallback: Extract posts if possible (e.g., from RealtimePostUpdate or PostCreated)
            // For simplicity, read current state and rebuild if it's a feed-like state
            final currentPosts = _extractPostsFromState(state);
            return FeedList(
              posts: currentPosts,
              userId: _userId!, // Pass userId
              hasMore: false,
              isRealtimeActive: false,
              onLoadMore: () {}, // Disabled in fallback
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Constants.createPostRoute),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<PostEntity> _extractPostsFromState(PostsState state) {
    // Helper to pull posts from various states (extend as needed)
    return switch (state) {
      FeedLoaded(:final posts) => posts,
      ReelsLoaded(:final posts) => posts, // If applicable
      UserPostsLoaded(:final posts) => posts,
      _ => <PostEntity>[],
    };
  }
}
