import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/widgets/feed_list.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
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
  final List<PostEntity> _posts = [];
  bool _notificationsSubscribed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing FeedPage');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthBloc>().cachedUser?.id;
      if (userId != null) {
        // Only request feed; RealtimeService and PostsBloc real-time listeners
        // are started globally from main.dart on auth.
        context.read<PostsBloc>().add(GetFeedEvent(userId));
        _subscribeNotifications();
      } else {
        AppLogger.warning(
          'FeedPage: userId null at init; waiting for AuthBloc',
        );
      }
    });
  }

  void _subscribeNotifications() {
    if (!_notificationsSubscribed && mounted) {
      try {
        context.read<NotificationsBloc>().add(NotificationsSubscribeStream());
        _notificationsSubscribed = true;
        AppLogger.info(
          'Dispatched NotificationsSubscribeStream from FeedPage.',
        );
      } catch (e) {
        AppLogger.error(
          'Failed to dispatch NotificationsSubscribeStream: $e',
          error: e,
        );
      }
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
        'Updating posts list. Old: ${oldIds.length}, New: ${newIds.length}',
      );
      setState(() {
        _posts
          ..clear()
          ..addAll(newPosts);
      });
    }
  }

  /// Only update boolean flags (isLiked/isFavorited) here.
  /// Counts are authoritative and come from RealtimePostUpdate (PostsBloc).
  void _applyPostFlags(String postId, {bool? isLiked, bool? isFavorited}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1 || !mounted) return;
    final old = _posts[index];
    final updated = old.copyWith(
      isLiked: isLiked ?? old.isLiked,
      isFavorited: isFavorited ?? old.isFavorited,
    );
    setState(() => _posts[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = context.select((AuthBloc b) => b.cachedUser?.id);
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final postsState = context.watch<PostsBloc>().state;
    final bool realtimeActive =
        postsState is FeedLoaded && postsState.isRealtimeActive;

    return Scaffold(
      appBar: AppBar(
        title: const UserGreetingTitle(),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        actions: [
          const NotificationIconWithBadge(),
          if (realtimeActive)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is FeedLoaded) {
                AppLogger.info(
                  'Feed loaded with ${state.posts.length} posts for user: $currentUserId',
                );
                _updatePosts(state.posts);
              } else if (state is PostCreated) {
                final exists = _posts.any((p) => p.id == state.post.id);
                if (!exists && mounted) {
                  setState(() => _posts.insert(0, state.post));
                }
                SnackbarUtils.showSuccess(
                  context,
                  'Post created successfully!',
                );
              } else if (state is RealtimePostUpdate) {
                // Authoritative counts (server-driven). Overwrite counts to keep
                // all UI surfaces consistent.
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted) {
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
                final index = _posts.indexWhere((p) => p.id == state.postId);
                if (index != -1 && mounted)
                  setState(() => _posts.removeAt(index));
              } else if (state is PostsError) {
                AppLogger.error('PostsError in FeedPage: ${state.message}');
              }
            },
          ),

          // LikesBloc: only sync the boolean flag at page-level.
          // Optimistic deltas are handled by item widgets (PostCard).
          BlocListener<LikesBloc, LikesState>(
            listener: (context, state) {
              if (state is LikeUpdated) {
                _applyPostFlags(state.postId, isLiked: state.isLiked);
              } else if (state is LikeSuccess) {
                _applyPostFlags(state.postId, isLiked: state.isLiked);
              } else if (state is LikeError) {
                AppLogger.error('Like error in FeedPage: ${state.message}');
                if (state.shouldRevert) {
                  _applyPostFlags(state.postId, isLiked: state.previousState);
                }
              }
            },
          ),

          // FavoritesBloc: only sync the boolean flag at page-level.
          // Counts are server-authoritative and will be applied by RealtimePostUpdate.
          BlocListener<FavoritesBloc, FavoritesState>(
            listener: (context, state) {
              if (state is FavoriteSuccess) {
                _applyPostFlags(state.postId, isFavorited: state.isFavorited);
              } else if (state is FavoriteUpdated) {
                // Do not change counts here — item widgets manage optimistic counts.
                _applyPostFlags(state.postId, isFavorited: state.isFavorited);
              } else if (state is FavoriteError) {
                AppLogger.error('Favorite error in FeedPage: ${state.message}');
                if (state.shouldRevert) {
                  _applyPostFlags(
                    state.postId,
                    isFavorited: state.previousState,
                  );
                }
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Refreshing feed for user: $currentUserId');
            final bloc = context.read<PostsBloc>();
            bloc.add(GetFeedEvent(currentUserId));
            await bloc.stream.firstWhere(
              (state) => state is FeedLoaded || state is PostsError,
            );
          },
          child: Builder(
            builder: (context) {
              if (_posts.isNotEmpty)
                return FeedList(posts: _posts, userId: currentUserId);

              final postsState = context.watch<PostsBloc>().state;
              if (postsState is PostsLoading || postsState is PostsInitial)
                return const LoadingIndicator();

              if (postsState is FeedLoaded) {
                if (postsState.posts.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No posts yet. Create one to get started!',
                    icon: Icons.post_add,
                  );
                }
                return FeedList(posts: postsState.posts, userId: currentUserId);
              }

              if (postsState is PostsError) {
                return CustomErrorWidget(
                  message: postsState.message,
                  onRetry: () => context.read<PostsBloc>().add(
                    GetFeedEvent(currentUserId),
                  ),
                );
              }

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
