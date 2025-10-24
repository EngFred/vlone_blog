import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
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
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_post_deletions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/stream_posts_usecase.dart';

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

  // Real-time use cases
  final StreamNewPostsUseCase streamNewPostsUseCase;
  final StreamPostUpdatesUseCase streamPostUpdatesUseCase;
  final StreamPostDeletionsUseCase streamPostDeletionsUseCase;

  // Stream subscriptions for cleanup
  StreamSubscription? _newPostsSubscription;
  StreamSubscription? _postUpdatesSubscription;
  StreamSubscription? _postDeletionsSubscription;

  PostsBloc({
    required this.createPostUseCase,
    required this.getFeedUseCase,
    required this.getReelsUseCase,
    required this.getUserPostsUseCase,
    required this.sharePostUseCase,
    required this.getPostUseCase,
    required this.deletePostUseCase,
    required this.streamNewPostsUseCase,
    required this.streamPostUpdatesUseCase,
    required this.streamPostDeletionsUseCase,
  }) : super(const PostsInitial()) {
    on<CreatePostEvent>(_onCreatePost);
    on<GetFeedEvent>(_onGetFeed);
    on<GetReelsEvent>(_onGetReels);
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<SharePostEvent>(_onSharePost);

    // Real-time event handlers
    on<StartRealtimeListenersEvent>(_onStartRealtimeListeners);
    on<StopRealtimeListenersEvent>(_onStopRealtimeListeners);
    on<_RealtimePostReceivedEvent>(_onRealtimePostReceived);
    on<_RealtimePostUpdatedEvent>(_onRealtimePostUpdated);
    on<_RealtimePostDeletedEvent>(_onRealtimePostDeleted);
  }

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

  // ==================== REAL-TIME HANDLERS ====================

  Future<void> _onStartRealtimeListeners(
    StartRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('Starting real-time listeners');

    // Cancel existing subscriptions
    await _cancelAllSubscriptions();

    // Subscribe to new posts
    _newPostsSubscription = streamNewPostsUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time new post error: ${failure.message}'),
          (post) {
            AppLogger.info('Real-time: New post received: ${post.id}');
            add(_RealtimePostReceivedEvent(post));
          },
        );
      },
      onError: (error) {
        AppLogger.error('New posts stream error: $error', error: error);
      },
    );

    // Subscribe to post updates (counts)
    _postUpdatesSubscription = streamPostUpdatesUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) => AppLogger.error(
            'Real-time post update error: ${failure.message}',
          ),
          (updateData) {
            AppLogger.info(
              'Real-time: Post update received for: ${updateData['id']}',
            );

            // Helper function to safely parse values that should be integers
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
        );
      },
      onError: (error) {
        AppLogger.error('Post updates stream error: $error', error: error);
      },
    );

    // Subscribe to post deletions
    _postDeletionsSubscription = streamPostDeletionsUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) => AppLogger.error(
            'Real-time post deletion error: ${failure.message}',
          ),
          (postId) {
            AppLogger.info('Real-time: Post deleted: $postId');
            add(_RealtimePostDeletedEvent(postId));
          },
        );
      },
      onError: (error) {
        AppLogger.error('Post deletions stream error: $error', error: error);
      },
    );

    AppLogger.info('Real-time listeners started successfully');

    // Re-emit current state with real-time active flag
    if (state is FeedLoaded) {
      emit(FeedLoaded((state as FeedLoaded).posts, isRealtimeActive: true));
    } else if (state is ReelsLoaded) {
      emit(ReelsLoaded((state as ReelsLoaded).posts, isRealtimeActive: true));
    }
  }

  Future<void> _onStopRealtimeListeners(
    StopRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('Stopping real-time listeners');
    await _cancelAllSubscriptions();

    // Re-emit current state with real-time inactive flag
    if (state is FeedLoaded) {
      emit(FeedLoaded((state as FeedLoaded).posts, isRealtimeActive: false));
    } else if (state is ReelsLoaded) {
      emit(ReelsLoaded((state as ReelsLoaded).posts, isRealtimeActive: false));
    }
  }

  Future<void> _onRealtimePostReceived(
    _RealtimePostReceivedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final currentState = state;

    // Add new post to feed if we're in FeedLoaded state
    if (currentState is FeedLoaded) {
      final exists = currentState.posts.any((p) => p.id == event.post.id);
      if (!exists) {
        final updatedPosts = [event.post, ...currentState.posts];
        emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info('New post added to feed: ${event.post.id}');
      }
    }

    // Similar logic for ReelsLoaded if it's a video post
    if (currentState is ReelsLoaded && event.post.mediaType == 'video') {
      final exists = currentState.posts.any((p) => p.id == event.post.id);
      if (!exists) {
        final updatedPosts = [event.post, ...currentState.posts];
        emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info('New reel added: ${event.post.id}');
      }
    }
  }

  void _onRealtimePostUpdated(
    _RealtimePostUpdatedEvent event,
    Emitter<PostsState> emit,
  ) {
    final currentState = state;

    if (currentState is FeedLoaded) {
      final updatedPosts = currentState.posts.map((post) {
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

      emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
      AppLogger.info('Post counts updated for: ${event.postId}');
    }

    if (currentState is ReelsLoaded) {
      final updatedPosts = currentState.posts.map((post) {
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

      emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
      AppLogger.info('Reel counts updated for: ${event.postId}');
    }

    if (currentState is UserPostsLoaded) {
      final updatedPosts = currentState.posts.map((post) {
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

      emit(UserPostsLoaded(updatedPosts));
      AppLogger.info('User post counts updated for: ${event.postId}');
    }

    // Emit update notification for widgets that need granular updates
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
          .where((post) => post.id != event.postId)
          .toList();
      emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
      AppLogger.info('Post removed from feed: ${event.postId}');
    }

    if (currentState is ReelsLoaded) {
      final updatedPosts = currentState.posts
          .where((post) => post.id != event.postId)
          .toList();
      emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
      AppLogger.info('Reel removed: ${event.postId}');
    }

    if (currentState is UserPostsLoaded) {
      final updatedPosts = currentState.posts
          .where((post) => post.id != event.postId)
          .toList();
      emit(UserPostsLoaded(updatedPosts));
      AppLogger.info('User post removed: ${event.postId}');
    }
  }

  Future<void> _cancelAllSubscriptions() async {
    await _newPostsSubscription?.cancel();
    await _postUpdatesSubscription?.cancel();
    await _postDeletionsSubscription?.cancel();

    _newPostsSubscription = null;
    _postUpdatesSubscription = null;
    _postDeletionsSubscription = null;
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing PostsBloc - cancelling all subscriptions');
    _cancelAllSubscriptions();
    return super.close();
  }
}
