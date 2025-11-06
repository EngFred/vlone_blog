import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed/feed_list.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed/notification_icon_with_badge.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed/user_greeting_title.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String? _userId;
  static const Duration _loadMoreDebounceDuration = Duration(milliseconds: 300);
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
        setState(() {}); // For _userId null check in build
        context.read<NotificationsBloc>().add(
          NotificationsSubscribeUnreadCountStream(),
        );

        if (context.read<FeedBloc>().state is FeedInitial) {
          context.read<FeedBloc>().add(GetFeedEvent(_userId!));
        }
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
        Debouncer.instance.debounce(
          'load_more_feed',
          _loadMoreDebounceDuration,
          () {
            final currentState = context.read<FeedBloc>().state;

            // Determining if we can load more from the BLoC state
            final bool hasMore = (currentState is FeedLoaded)
                ? currentState.hasMore
                : (currentState is FeedLoadingMore ||
                      currentState is FeedLoadMoreError)
                ? true
                : false;

            if (!hasMore) return;
            if (_isLoadingMore) return;
            if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 200) {
              AppLogger.info(
                'FeedPage: near bottom; dispatching LoadMoreFeedEvent',
              );

              // Set local UI state
              setState(() {
                _isLoadingMore = true;
              });
              context.read<FeedBloc>().add(const LoadMoreFeedEvent());
            }
          },
        );
      }
    });
  }

  // Fallback mechanism to ensure Realtime starts
  void _ensureRealtimeActive(FeedState state) {
    // Read realtime status *from the BLoC state*
    if (state is FeedLoaded && !state.isRealtimeActive && _userId != null) {
      AppLogger.warning(
        'FeedPage: Realtime was not active after load. Starting as fallback.',
      );
      context.read<FeedBloc>().add(const StartFeedRealtime());
    }
  }

  Future<void> _onRefresh() async {
    final authState = context.read<AuthBloc>().state;
    final userId = _extractUserId(authState);
    if (userId != null) {
      final completer = Completer<void>();
      context.read<FeedBloc>().add(
        RefreshFeedEvent(userId, refreshCompleter: completer),
      );
      return completer.future;
    }
  }

  @override
  void dispose() {
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
              const LoadingIndicator(size: 32),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              // 1. Handle Refresh Completer Completion
              final completer = (state is FeedLoaded)
                  ? state.refreshCompleter
                  : (state is FeedError)
                  ? state.refreshCompleter
                  : null;
              completer?.complete();

              // 2. Manage _isLoadingMore flag
              if (_isLoadingMore &&
                  (state is FeedLoaded || state is FeedLoadMoreError)) {
                setState(() {
                  _isLoadingMore = false;
                });
              }

              // 3. Fallback check
              if (state is FeedLoaded) {
                _ensureRealtimeActive(state);
              }

              // 4. Show snackbar for refresh errors when we have existing posts
              if (state is FeedError && _hasExistingPosts(state)) {
                _showRefreshErrorSnackbar(context, state.message);
              }
            },
          ),
        ],
        child: RefreshIndicator(
          backgroundColor: Theme.of(context).colorScheme.surface,
          color: Theme.of(context).colorScheme.primary,
          onRefresh: _onRefresh,
          child: Builder(
            builder: (context) {
              final feedState = context.watch<FeedBloc>().state;

              // Not showing full-screen loading if we are refreshing or loading more
              if (feedState is FeedLoading || feedState is FeedInitial) {
                if (feedState is FeedLoading &&
                    context.read<FeedBloc>().state is! FeedLoaded) {
                  return const Center(child: LoadingIndicator(size: 32));
                }
                if (feedState is FeedInitial) {
                  return const Center(child: LoadingIndicator(size: 32));
                }
              }

              if (feedState is FeedError) {
                // Only show full error widget if the list is completely empty
                final existingPosts = _getPostsFromState(feedState);
                if (existingPosts.isEmpty) {
                  return CustomErrorWidget(
                    message: feedState.message,
                    onRetry: _onRefresh,
                  );
                }
                // If not empty, we'll show the existing posts and a snackbar
              }

              // These states all contain a list of posts to display.
              if (feedState is FeedLoaded ||
                  feedState is FeedLoadingMore ||
                  feedState is FeedLoadMoreError ||
                  feedState is FeedError) {
                // Include FeedError to show existing list on refresh failure

                // Extract data based on the state type
                final List<PostEntity> posts = _getPostsFromState(feedState);

                final bool hasMore = (feedState is FeedLoaded)
                    ? feedState.hasMore
                    : (feedState is FeedLoadMoreError ||
                          feedState is FeedLoadingMore)
                    ? true // Keeps "load more" active if we're in a loading/error state
                    : false;

                final bool isRealtimeActive = (feedState is FeedLoaded)
                    ? feedState.isRealtimeActive
                    : false;

                final String? loadMoreError = (feedState is FeedLoadMoreError)
                    ? feedState.message
                    : null;

                if (posts.isEmpty) {
                  return EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                    actionText: 'Create Post',
                  );
                }

                // Passing the BLoC's data *directly* to the FeedList
                return FeedList(
                  posts: posts,
                  userId: _userId!,
                  hasMore: hasMore,
                  isRealtimeActive: isRealtimeActive,
                  loadMoreError: loadMoreError,
                  onLoadMore: () {
                    if (_isLoadingMore) return;
                    setState(() {
                      _isLoadingMore = true;
                    });
                    context.read<FeedBloc>().add(const LoadMoreFeedEvent());
                  },
                  controller: _scrollController,
                );
              }

              // Fallback for any unhandled state
              return const Center(child: LoadingIndicator());
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Constants.createPostRoute),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 8,
        label: const Text(
          'Create',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  bool _hasExistingPosts(FeedState state) {
    return _getPostsFromState(state).isNotEmpty;
  }

  List<PostEntity> _getPostsFromState(FeedState state) {
    if (state is FeedLoaded) {
      return state.posts;
    } else if (state is FeedLoadingMore) {
      return state.posts;
    } else if (state is FeedLoadMoreError) {
      return state.posts;
    } else if (state is FeedError) {
      // Extract posts from previous state if available in FeedError
      // This requires modifying FeedError to include posts
      return state.posts;
    }
    return [];
  }

  void _showRefreshErrorSnackbar(BuildContext context, String message) {
    SnackbarUtils.showError(
      context,
      'Refresh failed: $message',
      action: SnackBarAction(label: 'Retry', onPressed: _onRefresh),
      durationSeconds: 4,
    );
  }
}
