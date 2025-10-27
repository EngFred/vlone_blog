import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/delete_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';

part 'posts_event.dart';
part 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final CreatePostUseCase createPostUseCase;
  final GetFeedUseCase getFeedUseCase;
  final GetReelsUseCase getReelsUseCase;
  final GetUserPostsUseCase getUserPostsUseCase;
  final SharePostUseCase sharePostUseCase;
  final GetPostUseCase getPostUseCase;
  final DeletePostUseCase deletePostUseCase;

  // The single source-of-truth realtime service
  final RealtimeService realtimeService;

  // Subscriptions to RealtimeService's broadcast streams (per bloc instance)
  StreamSubscription<PostEntity>? _realtimeNewPostSub;
  StreamSubscription<Map<String, dynamic>>? _realtimePostUpdateSub;
  StreamSubscription<String>? _realtimePostDeletedSub;

  bool _isSubscribedToService = false;

  PostsBloc({
    required this.createPostUseCase,
    required this.getFeedUseCase,
    required this.getReelsUseCase,
    required this.getUserPostsUseCase,
    required this.sharePostUseCase,
    required this.getPostUseCase,
    required this.deletePostUseCase,
    required this.realtimeService,
  }) : super(const PostsInitial()) {
    // Core handlers
    on<CreatePostEvent>(_onCreatePost);
    on<GetFeedEvent>(_onGetFeed);
    on<GetReelsEvent>(_onGetReels);
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<SharePostEvent>(_onSharePost);

    // Optimistic update handler (added)
    on<OptimisticPostUpdate>(_onOptimisticPostUpdate);

    // Real-time handlers (subscribe/unsubscribe to RealtimeService)
    on<StartRealtimeListenersEvent>(_onStartRealtimeListeners);
    on<StopRealtimeListenersEvent>(_onStopRealtimeListeners);
    on<_RealtimePostReceivedEvent>(_onRealtimePostReceived);
    on<_RealtimePostUpdatedEvent>(_onRealtimePostUpdated);
    on<_RealtimePostDeletedEvent>(_onRealtimePostDeleted);
  }

  // -------------------------
  // Core use-case handlers
  // -------------------------
  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('CreatePostEvent triggered for user: ${event.userId}');
    emit(const PostsLoading());

    final result = await createPostUseCase(
      CreatePostParams(
        userId: event.userId,
        content: event.content,
        mediaFile: event.mediaFile,
        mediaType: event.mediaType,
      ),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Create post failed: $friendlyMessage');
        emit(PostsError(friendlyMessage));
      },
      (post) {
        AppLogger.info('Post created successfully: ${post.id}');
        emit(PostCreated(post));
      },
    );
  }

  Future<void> _onGetFeed(GetFeedEvent event, Emitter<PostsState> emit) async {
    AppLogger.info('GetFeedEvent triggered');
    emit(const PostsLoading());

    final result = await getFeedUseCase(
      GetFeedParams(currentUserId: event.userId),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get feed failed: $friendlyMessage');
        emit(PostsError(friendlyMessage));
      },
      (posts) {
        AppLogger.info('Feed loaded with ${posts.length} posts');
        emit(FeedLoaded(posts));
      },
    );
  }

  Future<void> _onGetReels(
    GetReelsEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('GetReelsEvent triggered');
    emit(const PostsLoading());

    final result = await getReelsUseCase(
      GetReelsParams(currentUserId: event.userId),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get reels failed: $friendlyMessage');
        emit(PostsError(friendlyMessage));
      },
      (posts) {
        AppLogger.info('Reels loaded with ${posts.length} posts');
        emit(ReelsLoaded(posts));
      },
    );
  }

  Future<void> _onGetUserPosts(
    GetUserPostsEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info(
      'GetUserPostsEvent triggered for user: ${event.profileUserId}',
    );
    emit(const UserPostsLoading());

    final result = await getUserPostsUseCase(
      GetUserPostsParams(
        profileUserId: event.profileUserId,
        currentUserId: event.currentUserId,
      ),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get user posts failed: $friendlyMessage');
        emit(UserPostsError(friendlyMessage));
      },
      (posts) {
        AppLogger.info('User posts loaded with ${posts.length} posts');
        emit(UserPostsLoaded(posts));
      },
    );
  }

  Future<void> _onGetPost(GetPostEvent event, Emitter<PostsState> emit) async {
    AppLogger.info('GetPostEvent for post: ${event.postId}');

    final result = await getPostUseCase(
      GetPostParams(postId: event.postId, currentUserId: event.currentUserId),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get post failed: $friendlyMessage');
        emit(PostsError(friendlyMessage));
      },
      (post) {
        AppLogger.info('Post loaded: ${post.id}');
        emit(PostLoaded(post));
      },
    );
  }

  Future<void> _onDeletePost(
    DeletePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('DeletePostEvent triggered for post: ${event.postId}');
    emit(PostDeleting(event.postId));

    final result = await deletePostUseCase(
      DeletePostParams(postId: event.postId),
    );

    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Delete post failed: ${failure.message}');
        emit(PostDeleteError(event.postId, friendlyMessage));
      },
      (_) {
        AppLogger.info('Post deleted successfully: ${event.postId}');
        emit(PostDeleted(event.postId));
      },
    );
  }

  Future<void> _onSharePost(
    SharePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('SharePostEvent triggered for post: ${event.postId}');

    final result = await sharePostUseCase(
      SharePostParams(postId: event.postId),
    );

    result.fold(
      (failure) {
        AppLogger.error('Share post failed: ${failure.message}');
        emit(PostShareError(event.postId, failure.message));
      },
      (_) {
        AppLogger.info('Post shared successfully');
        emit(PostShared(event.postId));
      },
    );
  }

  // -------------------------
  // Optimistic update handler
  // -------------------------
  Future<void> _onOptimisticPostUpdate(
    OptimisticPostUpdate event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final currentState = state;

      List<PostEntity> _apply(List<PostEntity> list) {
        return list.map((p) {
          if (p.id != event.postId) return p;

          final int newLikes = (p.likesCount + (event.deltaLikes))
              .clamp(0, double.infinity)
              .toInt();
          final int newFavorites = (p.favoritesCount + (event.deltaFavorites))
              .clamp(0, double.infinity)
              .toInt();

          return p.copyWith(
            likesCount: newLikes,
            favoritesCount: newFavorites,
            isLiked: event.isLiked ?? p.isLiked,
            isFavorited: event.isFavorited ?? p.isFavorited,
          );
        }).toList();
      }

      if (currentState is FeedLoaded) {
        final updated = _apply(currentState.posts);
        emit(
          FeedLoaded(updated, isRealtimeActive: currentState.isRealtimeActive),
        );
        return;
      }

      if (currentState is ReelsLoaded) {
        final updated = _apply(currentState.posts);
        emit(
          ReelsLoaded(updated, isRealtimeActive: currentState.isRealtimeActive),
        );
        return;
      }

      if (currentState is UserPostsLoaded) {
        final updated = _apply(currentState.posts);
        emit(UserPostsLoaded(updated));
        return;
      }

      // If other states carry a posts list, handle them similarly.
      // Otherwise do nothing (optimistic change applies only to list states).
    } catch (e, st) {
      AppLogger.error(
        'Optimistic update failed in PostsBloc: $e',
        error: e,
        stackTrace: st,
      );
      // swallow — server updates will correct any mismatch
    }
  }

  // -------------------------
  // Real-time handlers (via RealtimeService)
  // -------------------------

  /// Subscribe to the RealtimeService broadcast streams.
  Future<void> _onStartRealtimeListeners(
    StartRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (_isSubscribedToService) {
      AppLogger.info(
        'PostsBloc: already subscribed to RealtimeService streams',
      );
      return;
    }

    AppLogger.info('PostsBloc: subscribing to RealtimeService streams');

    // Subscribe to new posts
    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) {
        add(_RealtimePostReceivedEvent(post));
      },
      onError: (e) =>
          AppLogger.error('RealtimeService onNewPost error: $e', error: e),
    );

    // Subscribe to post updates
    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen(
      (updateData) {
        int? safeParseInt(dynamic value) {
          if (value == null) return null;
          if (value is int) return value;
          return int.tryParse(value.toString().split('.').first);
        }

        add(
          _RealtimePostUpdatedEvent(
            postId: updateData['id'] as String,
            likesCount: safeParseInt(updateData['likes_count']),
            commentsCount: safeParseInt(updateData['comments_count']),
            favoritesCount: safeParseInt(updateData['favorites_count']),
            sharesCount: safeParseInt(updateData['shares_count']),
          ),
        );
      },
      onError: (e) =>
          AppLogger.error('RealtimeService onPostUpdate error: $e', error: e),
    );

    // Subscribe to deletions
    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) {
        add(_RealtimePostDeletedEvent(postId));
      },
      onError: (e) =>
          AppLogger.error('RealtimeService onPostDeleted error: $e', error: e),
    );

    _isSubscribedToService = true;

    // Re-emit state marking realtime active if appropriate
    if (state is FeedLoaded) {
      emit(
        FeedLoaded(
          (state as FeedLoaded).posts,
          isRealtimeActive: realtimeService.isStarted,
        ),
      );
    } else if (state is ReelsLoaded) {
      emit(
        ReelsLoaded(
          (state as ReelsLoaded).posts,
          isRealtimeActive: realtimeService.isStarted,
        ),
      );
    }

    AppLogger.info('PostsBloc: subscribed to RealtimeService');
  }

  /// Unsubscribe from RealtimeService (does NOT stop the service).
  Future<void> _onStopRealtimeListeners(
    StopRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (!_isSubscribedToService) {
      AppLogger.info('PostsBloc: stop requested but not subscribed');
      return;
    }

    AppLogger.info('PostsBloc: unsubscribing from RealtimeService streams');
    try {
      await _realtimeNewPostSub?.cancel();
      await _realtimePostUpdateSub?.cancel();
      await _realtimePostDeletedSub?.cancel();
    } catch (e) {
      AppLogger.warning('Error cancelling RealtimeService subs: $e');
    } finally {
      _realtimeNewPostSub = null;
      _realtimePostUpdateSub = null;
      _realtimePostDeletedSub = null;
      _isSubscribedToService = false;
    }

    // Re-emit state marking realtime inactive if appropriate
    if (state is FeedLoaded) {
      emit(FeedLoaded((state as FeedLoaded).posts, isRealtimeActive: false));
    } else if (state is ReelsLoaded) {
      emit(ReelsLoaded((state as ReelsLoaded).posts, isRealtimeActive: false));
    }

    AppLogger.info('PostsBloc: unsubscribed from RealtimeService');
  }

  Future<void> _onRealtimePostReceived(
    _RealtimePostReceivedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final currentState = state;

    if (currentState is FeedLoaded) {
      final exists = currentState.posts.any((p) => p.id == event.post.id);
      if (!exists) {
        final updatedPosts = [event.post, ...currentState.posts];
        emit(
          FeedLoaded(updatedPosts, isRealtimeActive: realtimeService.isStarted),
        );
        AppLogger.info('New post added to feed: ${event.post.id}');
      }
    }

    if (currentState is ReelsLoaded && event.post.mediaType == 'video') {
      final exists = currentState.posts.any((p) => p.id == event.post.id);
      if (!exists) {
        final updatedPosts = [event.post, ...currentState.posts];
        emit(
          ReelsLoaded(
            updatedPosts,
            isRealtimeActive: realtimeService.isStarted,
          ),
        );
        AppLogger.info('New reel added: ${event.post.id}');
      }
    }
  }

  void _onRealtimePostUpdated(
    _RealtimePostUpdatedEvent event,
    Emitter<PostsState> emit,
  ) {
    final currentState = state;

    List<PostEntity> _applyUpdate(List<PostEntity> posts) {
      return posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            likesCount: event.likesCount ?? post.likesCount,
            commentsCount: event.commentsCount ?? post.commentsCount,
            favoritesCount: event.favoritesCount ?? post.favoritesCount,
            sharesCount: event.sharesCount ?? post.sharesCount,
          );
        }
        return post;
      }).toList();
    }

    if (currentState is FeedLoaded) {
      emit(
        FeedLoaded(
          _applyUpdate(currentState.posts),
          isRealtimeActive: realtimeService.isStarted,
        ),
      );
      AppLogger.info('Post counts updated for: ${event.postId}');
    } else if (currentState is ReelsLoaded) {
      emit(
        ReelsLoaded(
          _applyUpdate(currentState.posts),
          isRealtimeActive: realtimeService.isStarted,
        ),
      );
      AppLogger.info('Reel counts updated for: ${event.postId}');
    } else if (currentState is UserPostsLoaded) {
      emit(UserPostsLoaded(_applyUpdate(currentState.posts)));
      AppLogger.info('User post counts updated for: ${event.postId}');
    }

    // Also emit granular update for widgets
    emit(
      RealtimePostUpdate(
        postId: event.postId,
        likesCount: event.likesCount,
        commentsCount: event.commentsCount,
        favoritesCount: event.favoritesCount,
        sharesCount: event.sharesCount,
      ),
    );
  }

  void _onRealtimePostDeleted(
    _RealtimePostDeletedEvent event,
    Emitter<PostsState> emit,
  ) {
    final currentState = state;

    if (currentState is FeedLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(
        FeedLoaded(updatedPosts, isRealtimeActive: realtimeService.isStarted),
      );
      AppLogger.info('Post removed from feed: ${event.postId}');
    } else if (currentState is ReelsLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(
        ReelsLoaded(updatedPosts, isRealtimeActive: realtimeService.isStarted),
      );
      AppLogger.info('Reel removed: ${event.postId}');
    } else if (currentState is UserPostsLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(UserPostsLoaded(updatedPosts));
      AppLogger.info('User post removed: ${event.postId}');
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing PostsBloc - cancelling realtime subscriptions');
    unawaited(_realtimeNewPostSub?.cancel());
    unawaited(_realtimePostUpdateSub?.cancel());
    unawaited(_realtimePostDeletedSub?.cancel());
    return super.close();
  }
}
