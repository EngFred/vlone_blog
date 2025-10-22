import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/create_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/favorite_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_interactions_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/share_post_usecase.dart';
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

  // Real-time use cases
  final StreamNewPostsUseCase streamNewPostsUseCase;
  final StreamPostUpdatesUseCase streamPostUpdatesUseCase;
  final StreamLikesUseCase streamLikesUseCase;
  final StreamCommentsUseCase streamCommentsUseCase;
  final StreamFavoritesUseCase streamFavoritesUseCase;

  // Stream subscriptions for cleanup
  StreamSubscription? _newPostsSubscription;
  StreamSubscription? _postUpdatesSubscription;
  StreamSubscription? _likesSubscription;
  StreamSubscription? _commentsSubscription;
  StreamSubscription? _favoritesSubscription;

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
    required this.streamNewPostsUseCase,
    required this.streamPostUpdatesUseCase,
    required this.streamLikesUseCase,
    required this.streamCommentsUseCase,
    required this.streamFavoritesUseCase,
  }) : super(PostsInitial()) {
    on<CreatePostEvent>(_onCreatePost);
    on<GetFeedEvent>(_onGetFeed);
    on<GetReelsEvent>(_onGetReels);
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<GetPostEvent>(_onGetPost);
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
        AppLogger.error('Create post failed: ${failure.message}');
        emit(PostsError(failure.message));
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

    await result.fold(
      (failure) async {
        AppLogger.error('Get feed failed: ${failure.message}');
        emit(PostsError(failure.message));
      },
      (posts) async {
        List<PostEntity> updatedPosts = posts;

        if (event.userId != null) {
          final postIds = posts.map((p) => p.id).toList();
          final interResult = await sl<GetPostInteractionsUseCase>()(
            GetPostInteractionsParams(userId: event.userId!, postIds: postIds),
          );

          interResult.fold(
            (failure) {
              AppLogger.error(
                'Failed to fetch interactions for feed: ${failure.message}',
              );
            },
            (states) {
              updatedPosts = posts
                  .map(
                    (p) => p.copyWith(
                      isLiked: states.isLiked(p.id),
                      isFavorited: states.isFavorited(p.id),
                    ),
                  )
                  .toList();
            },
          );
        }

        AppLogger.info('Feed loaded with ${updatedPosts.length} posts');
        emit(FeedLoaded(updatedPosts));
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

    await result.fold(
      (failure) async {
        AppLogger.error('Get reels failed: ${failure.message}');
        emit(PostsError(failure.message));
      },
      (posts) async {
        List<PostEntity> updatedPosts = posts;

        if (event.userId != null) {
          final postIds = posts.map((p) => p.id).toList();
          final interResult = await sl<GetPostInteractionsUseCase>()(
            GetPostInteractionsParams(userId: event.userId!, postIds: postIds),
          );

          interResult.fold(
            (failure) {
              AppLogger.error(
                'Failed to fetch interactions for reels: ${failure.message}',
              );
            },
            (states) {
              updatedPosts = posts
                  .map(
                    (p) => p.copyWith(
                      isLiked: states.isLiked(p.id),
                      isFavorited: states.isFavorited(p.id),
                    ),
                  )
                  .toList();
            },
          );
        }

        AppLogger.info('Reels loaded with ${updatedPosts.length} posts');
        emit(ReelsLoaded(updatedPosts));
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

    await result.fold(
      (failure) async {
        AppLogger.error('Get user posts failed: ${failure.message}');
        emit(UserPostsError(failure.message));
      },
      (posts) async {
        List<PostEntity> updatedPosts = posts;

        if (event.viewerUserId != null) {
          final postIds = posts.map((p) => p.id).toList();
          final interResult = await sl<GetPostInteractionsUseCase>()(
            GetPostInteractionsParams(
              userId: event.viewerUserId!,
              postIds: postIds,
            ),
          );

          interResult.fold(
            (failure) {
              AppLogger.error(
                'Failed to fetch interactions for user posts: ${failure.message}',
              );
            },
            (states) {
              updatedPosts = posts
                  .map(
                    (p) => p.copyWith(
                      isLiked: states.isLiked(p.id),
                      isFavorited: states.isFavorited(p.id),
                    ),
                  )
                  .toList();
            },
          );
        }

        AppLogger.info('User posts loaded with ${updatedPosts.length} posts');
        emit(UserPostsLoaded(updatedPosts));
      },
    );
  }

  Future<void> _onGetPost(GetPostEvent event, Emitter<PostsState> emit) async {
    AppLogger.info('GetPostEvent for post: ${event.postId}');

    final result = await getPostUseCase(event.postId);

    result.fold(
      (failure) {
        AppLogger.error('Get post failed: ${failure.message}');
        emit(PostsError(failure.message));
      },
      (post) async {
        PostEntity updatedPost = post;

        if (event.viewerUserId != null) {
          final interResult = await sl<GetPostInteractionsUseCase>()(
            GetPostInteractionsParams(
              userId: event.viewerUserId!,
              postIds: [post.id],
            ),
          );

          interResult.fold(
            (failure) => AppLogger.error(
              'Interactions fetch failed: ${failure.message}',
            ),
            (states) {
              updatedPost = post.copyWith(
                isLiked: states.isLiked(post.id),
                isFavorited: states.isFavorited(post.id),
              );
            },
          );
        }

        AppLogger.info('Post loaded: ${updatedPost.id}');
        emit(PostLoaded(updatedPost));
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
        // FIX: Log failure silently, no state emission for UX
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
        // FIX: Log failure silently, no state emission for UX
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
        // FIX: Log failure silently, no state emission for UX
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
            add(
              _RealtimePostUpdatedEvent(
                postId: updateData['id'] as String,
                likesCount: updateData['likes_count'] as int?,
                commentsCount: updateData['comments_count'] as int?,
                favoritesCount: updateData['favorites_count'] as int?,
                sharesCount: updateData['shares_count'] as int?,
              ),
            );
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

    // Add new post to feed if we're in FeedLoaded state
    if (currentState is FeedLoaded) {
      // Fetch interactions for the new post if we have a user
      PostEntity updatedPost = event.post;

      if (_currentUserId != null) {
        final interResult = await sl<GetPostInteractionsUseCase>()(
          GetPostInteractionsParams(
            userId: _currentUserId!,
            postIds: [event.post.id],
          ),
        );

        interResult.fold(
          (failure) => AppLogger.error(
            'Failed to fetch interactions for new post: ${failure.message}',
          ),
          (states) {
            updatedPost = event.post.copyWith(
              isLiked: states.isLiked(event.post.id),
              isFavorited: states.isFavorited(event.post.id),
            );
          },
        );
      }

      // Avoid duplicates
      final exists = currentState.posts.any((p) => p.id == updatedPost.id);
      if (!exists) {
        final updatedPosts = [updatedPost, ...currentState.posts];
        emit(FeedLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info('New post added to feed: ${updatedPost.id}');
      }
    }

    // Similar logic for ReelsLoaded if it's a video post
    if (currentState is ReelsLoaded && event.post.mediaType == 'video') {
      PostEntity updatedPost = event.post;

      if (_currentUserId != null) {
        final interResult = await sl<GetPostInteractionsUseCase>()(
          GetPostInteractionsParams(
            userId: _currentUserId!,
            postIds: [event.post.id],
          ),
        );

        interResult.fold(
          (failure) => AppLogger.error(
            'Failed to fetch interactions for new reel: ${failure.message}',
          ),
          (states) {
            updatedPost = event.post.copyWith(
              isLiked: states.isLiked(event.post.id),
              isFavorited: states.isFavorited(event.post.id),
            );
          },
        );
      }

      final exists = currentState.posts.any((p) => p.id == updatedPost.id);
      if (!exists) {
        final updatedPosts = [updatedPost, ...currentState.posts];
        emit(ReelsLoaded(updatedPosts, isRealtimeActive: true));
        AppLogger.info('New reel added: ${updatedPost.id}');
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

    _newPostsSubscription = null;
    _postUpdatesSubscription = null;
    _likesSubscription = null;
    _commentsSubscription = null;
    _favoritesSubscription = null;
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing PostsBloc - cancelling all subscriptions');
    _cancelAllSubscriptions();
    return super.close();
  }
}
