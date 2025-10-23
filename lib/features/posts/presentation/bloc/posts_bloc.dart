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
import 'package:vlone_blog_app/features/posts/domain/usecases/favorite_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/like_post_usecase.dart';
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
  final LikePostUseCase likePostUseCase;
  final FavoritePostUseCase favoritePostUseCase;
  final SharePostUseCase sharePostUseCase;
  final GetPostUseCase getPostUseCase;
  final DeletePostUseCase deletePostUseCase;

  // Real-time use cases
  final StreamNewPostsUseCase streamNewPostsUseCase;
  final StreamPostUpdatesUseCase streamPostUpdatesUseCase;
  final StreamLikesUseCase streamLikesUseCase;
  final StreamCommentsUseCase streamCommentsUseCase;
  final StreamFavoritesUseCase streamFavoritesUseCase;
  final StreamPostDeletionsUseCase streamPostDeletionsUseCase;

  // Stream subscriptions for cleanup
  StreamSubscription? _newPostsSubscription;
  StreamSubscription? _postUpdatesSubscription;
  StreamSubscription? _likesSubscription;
  StreamSubscription? _commentsSubscription;
  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _postDeletionsSubscription;

  // Track current user for real-time filtering
  String? _currentUserId;

  PostsBloc({
    required this.createPostUseCase,
    required this.getFeedUseCase,
    required this.getReelsUseCase,
    required this.getUserPostsUseCase,
    required this.likePostUseCase,
    required this.favoritePostUseCase,
    required this.sharePostUseCase,
    required this.getPostUseCase,
    required this.deletePostUseCase,
    required this.streamNewPostsUseCase,
    required this.streamPostUpdatesUseCase,
    required this.streamLikesUseCase,
    required this.streamCommentsUseCase,
    required this.streamFavoritesUseCase,
    required this.streamPostDeletionsUseCase,
  }) : super(PostsInitial()) {
    on<CreatePostEvent>(_onCreatePost);
    on<GetFeedEvent>(_onGetFeed);
    on<GetReelsEvent>(_onGetReels);
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<LikePostEvent>(_onLikePost);
    on<SharePostEvent>(_onSharePost);
    on<FavoritePostEvent>(_onFavoritePost);

    // Real-time event handlers
    on<StartRealtimeListenersEvent>(_onStartRealtimeListeners);
    on<StopRealtimeListenersEvent>(_onStopRealtimeListeners);
    on<_RealtimePostReceivedEvent>(_onRealtimePostReceived);
    on<_RealtimePostUpdatedEvent>(_onRealtimePostUpdated);
    on<_RealtimeLikeEvent>(_onRealtimeLike);
    on<_RealtimeCommentEvent>(_onRealtimeComment);
    on<_RealtimeFavoriteEvent>(_onRealtimeFavorite);
    on<_RealtimePostDeletedEvent>(_onRealtimePostDeleted);
  }

  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('CreatePostEvent triggered for user: ${event.userId}');
    emit(PostsLoading());

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
    emit(PostsLoading());

    final result = await getFeedUseCase(NoParams());

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
    emit(PostsLoading());

    final result = await getReelsUseCase(NoParams());

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
    emit(UserPostsLoading());

    final result = await getUserPostsUseCase(
      GetUserPostsParams(userId: event.profileUserId),
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

    final result = await getPostUseCase(event.postId);

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

  Future<void> _onLikePost(
    LikePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info(
      'LikePostEvent triggered for post: ${event.postId}, like: ${event.isLiked}',
    );

    final result = await likePostUseCase(
      LikePostParams(
        postId: event.postId,
        userId: event.userId,
        isLiked: event.isLiked,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.error('Like post failed: ${failure.message}');
      },
      (_) {
        AppLogger.info('Post liked/unliked successfully');
        emit(PostLiked(event.postId, event.isLiked));
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
      },
      (_) {
        AppLogger.info('Post shared successfully');
        emit(PostShared(event.postId));
      },
    );
  }

  Future<void> _onFavoritePost(
    FavoritePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info(
      'FavoritePostEvent triggered for post: ${event.postId}, favorite: ${event.isFavorited}',
    );

    final result = await favoritePostUseCase(
      FavoritePostParams(
        postId: event.postId,
        userId: event.userId,
        isFavorited: event.isFavorited,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.error('Favorite post failed: ${failure.message}');
      },
      (_) {
        AppLogger.info('Post favorited/unfavorited successfully');
        emit(PostFavorited(event.postId, event.isFavorited));
      },
    );
  }

  // ==================== REAL-TIME HANDLERS ====================

  Future<void> _onStartRealtimeListeners(
    StartRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('Starting real-time listeners');

    _currentUserId = event.userId;

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

            // ================== FIX 1 START ==================
            // Helper function to safely parse values that should be integers
            // This handles nulls, ints, doubles (e.g., 10.0), and strings (e.g., "10")
            int? safeParseInt(dynamic value) {
              if (value == null) return null;
              if (value is int) return value;
              // Handle doubles and strings
              return int.tryParse(value.toString().split('.').first);
            }

            add(
              _RealtimePostUpdatedEvent(
                postId: updateData['id'] as String,
                // Use the safe parser for all count fields
                likesCount: safeParseInt(updateData['likes_count']),
                commentsCount: safeParseInt(updateData['comments_count']),
                favoritesCount: safeParseInt(updateData['favorites_count']),
                sharesCount: safeParseInt(updateData['shares_count']),
              ),
            );
            // ================== FIX 1 END ==================
          },
        );
      },
      onError: (error) {
        AppLogger.error('Post updates stream error: $error', error: error);
      },
    );

    // Subscribe to likes
    _likesSubscription = streamLikesUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time like error: ${failure.message}'),
          (likeData) {
            final isLiked = likeData['event'] == 'INSERT';
            AppLogger.info(
              'Real-time: Like ${isLiked ? 'added' : 'removed'} on post: ${likeData['post_id']}',
            );
            add(
              _RealtimeLikeEvent(
                postId: likeData['post_id'] as String,
                userId: likeData['user_id'] as String,
                isLiked: isLiked,
              ),
            );
          },
        );
      },
      onError: (error) {
        AppLogger.error('Likes stream error: $error', error: error);
      },
    );

    // Subscribe to comments
    _commentsSubscription = streamCommentsUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time comment error: ${failure.message}'),
          (commentData) {
            AppLogger.info(
              'Real-time: Comment added to post: ${commentData['post_id']}',
            );
            add(_RealtimeCommentEvent(commentData['post_id'] as String));
          },
        );
      },
      onError: (error) {
        AppLogger.error('Comments stream error: $error', error: error);
      },
    );

    // Subscribe to favorites
    _favoritesSubscription = streamFavoritesUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time favorite error: ${failure.message}'),
          (favoriteData) {
            final isFavorited = favoriteData['event'] == 'INSERT';
            AppLogger.info(
              'Real-time: Favorite ${isFavorited ? 'added' : 'removed'} on post: ${favoriteData['post_id']}',
            );
            add(
              _RealtimeFavoriteEvent(
                postId: favoriteData['post_id'] as String,
                userId: favoriteData['user_id'] as String,
                isFavorited: isFavorited,
              ),
            );
          },
        );
      },
      onError: (error) {
        AppLogger.error('Favorites stream error: $error', error: error);
      },
    );

    // ================== FIX 2 START ==================
    // Subscribe to post deletions
    _postDeletionsSubscription = streamPostDeletionsUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) => AppLogger.error(
            'Real-time post deletion error: ${failure.message}',
          ),
          // The data from this stream is just the String postId, not a Map.
          (postId) {
            AppLogger.info('Real-time: Post deleted: $postId');
            add(_RealtimePostDeletedEvent(postId)); // Pass the string directly
          },
        );
      },
      onError: (error) {
        AppLogger.error('Post deletions stream error: $error', error: error);
      },
    );
    // ================== FIX 2 END ==================

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
    _currentUserId = null;

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

    // Add new post to feed if we're in FeedLoaded state (with default interaction states)
    if (currentState is FeedLoaded) {
      // Avoid duplicates
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

  void _onRealtimeLike(_RealtimeLikeEvent event, Emitter<PostsState> emit) {
    final currentState = state;

    // Only update if this like is from the current user
    if (event.userId == _currentUserId) {
      if (currentState is FeedLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isLiked: event.isLiked);
          }
          return post;
        }).toList();

        emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info(
          'Like state updated for current user on post: ${event.postId}',
        );
      }

      if (currentState is ReelsLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isLiked: event.isLiked);
          }
          return post;
        }).toList();

        emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info(
          'Like state updated for current user on reel: ${event.postId}',
        );
      }

      if (currentState is UserPostsLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isLiked: event.isLiked);
          }
          return post;
        }).toList();

        emit(UserPostsLoaded(updatedPosts));
        AppLogger.info(
          'Like state updated for current user on user post: ${event.postId}',
        );
      }
    }
  }

  void _onRealtimeComment(
    _RealtimeCommentEvent event,
    Emitter<PostsState> emit,
  ) {
    // Comment count updates are handled by _onRealtimePostUpdated
    // This is just for logging/notifications if needed
    AppLogger.info('Real-time comment event processed for: ${event.postId}');
  }

  void _onRealtimeFavorite(
    _RealtimeFavoriteEvent event,
    Emitter<PostsState> emit,
  ) {
    final currentState = state;

    // Only update if this favorite is from the current user
    if (event.userId == _currentUserId) {
      if (currentState is FeedLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isFavorited: event.isFavorited);
          }
          return post;
        }).toList();

        emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info(
          'Favorite state updated for current user on post: ${event.postId}',
        );
      }

      if (currentState is ReelsLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isFavorited: event.isFavorited);
          }
          return post;
        }).toList();

        emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info(
          'Favorite state updated for current user on reel: ${event.postId}',
        );
      }

      if (currentState is UserPostsLoaded) {
        final updatedPosts = currentState.posts.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(isFavorited: event.isFavorited);
          }
          return post;
        }).toList();

        emit(UserPostsLoaded(updatedPosts));
        AppLogger.info(
          'Favorite state updated for current user on user post: ${event.postId}',
        );
      }
    }
  }

  Future<void> _cancelAllSubscriptions() async {
    await _newPostsSubscription?.cancel();
    await _postUpdatesSubscription?.cancel();
    await _likesSubscription?.cancel();
    await _commentsSubscription?.cancel();
    await _favoritesSubscription?.cancel();
    await _postDeletionsSubscription?.cancel();

    _newPostsSubscription = null;
    _postUpdatesSubscription = null;
    _likesSubscription = null;
    _commentsSubscription = null;
    _favoritesSubscription = null;
    _postDeletionsSubscription = null;
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing PostsBloc - cancelling all subscriptions');
    _cancelAllSubscriptions();
    return super.close();
  }
}
