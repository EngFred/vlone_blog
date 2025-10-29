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

  // Pagination state for Feed
  static const int _pageSize = 20;
  bool _hasMoreFeed = true;
  DateTime? _lastFeedCreatedAt;
  String? _lastFeedId;
  String? _currentFeedUserId;

  // Pagination state for Reels
  bool _hasMoreReels = true;
  DateTime? _lastReelsCreatedAt;
  String? _lastReelsId;
  String? _currentReelsUserId;

  // Pagination state for User Posts
  bool _hasMoreUserPosts = true;
  DateTime? _lastUserPostsCreatedAt;
  String? _lastUserPostsId;
  String? _currentUserPostsProfileId;
  String? _currentUserPostsUserId;

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
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<GetReelsEvent>(_onGetReels);
    on<LoadMoreReelsEvent>(_onLoadMoreReels);
    on<RefreshReelsEvent>(_onRefreshReels);
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<LoadMoreUserPostsEvent>(_onLoadMoreUserPosts);
    on<RefreshUserPostsEvent>(_onRefreshUserPosts);
    on<GetPostEvent>(_onGetPost);
    on<DeletePostEvent>(_onDeletePost);
    on<SharePostEvent>(_onSharePost);
    // Optimistic update handler
    on<OptimisticPostUpdate>(_onOptimisticPostUpdate);
    // Real-time handlers
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
    _currentFeedUserId = event.userId;
    emit(const PostsLoading());
    await _fetchFeed(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreFeed(
    LoadMoreFeedEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (_currentFeedUserId == null || !_hasMoreFeed || state is FeedLoadingMore)
      return;
    emit(const FeedLoadingMore());
    await _fetchFeed(emit, isRefresh: false);
  }

  Future<void> _onRefreshFeed(
    RefreshFeedEvent event,
    Emitter<PostsState> emit,
  ) async {
    _currentFeedUserId = event.userId;
    _hasMoreFeed = true;
    _lastFeedCreatedAt = null;
    _lastFeedId = null;
    emit(const PostsLoading());
    await _fetchFeed(emit, isRefresh: true);
  }

  Future<void> _fetchFeed(
    Emitter<PostsState> emit, {
    required bool isRefresh,
  }) async {
    final result = await getFeedUseCase(
      GetFeedParams(
        currentUserId: _currentFeedUserId!,
        pageSize: _pageSize,
        lastCreatedAt: _lastFeedCreatedAt,
        lastId: _lastFeedId,
      ),
    );
    result.fold(
      (failure) {
        final message = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get feed failed: $message');
        if (isRefresh) {
          emit(PostsError(message));
        } else {
          emit(
            FeedLoadMoreError(
              message,
              currentPosts: state is FeedLoaded
                  ? List<PostEntity>.from((state as FeedLoaded).posts)
                  : [],
            ),
          );
        }
      },
      (newPosts) {
        List<PostEntity> updatedPosts;
        if (isRefresh) {
          updatedPosts = newPosts;
        } else {
          updatedPosts = state is FeedLoaded
              ? List<PostEntity>.from((state as FeedLoaded).posts)
              : <PostEntity>[];
          updatedPosts.addAll(newPosts);
        }
        if (newPosts.isNotEmpty) {
          _lastFeedCreatedAt = newPosts.last.createdAt;
          _lastFeedId = newPosts.last.id;
        }
        _hasMoreFeed = newPosts.length == _pageSize;
        emit(
          FeedLoaded(
            updatedPosts,
            hasMore: _hasMoreFeed,
            isRealtimeActive: _isSubscribedToService,
          ),
        );
        AppLogger.info('Feed loaded with ${updatedPosts.length} posts');
      },
    );
  }

  Future<void> _onGetReels(
    GetReelsEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info('GetReelsEvent triggered');
    _currentReelsUserId = event.userId;
    emit(const PostsLoading());
    await _fetchReels(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreReels(
    LoadMoreReelsEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (_currentReelsUserId == null ||
        !_hasMoreReels ||
        state is ReelsLoadingMore)
      return;
    emit(const ReelsLoadingMore());
    await _fetchReels(emit, isRefresh: false);
  }

  Future<void> _onRefreshReels(
    RefreshReelsEvent event,
    Emitter<PostsState> emit,
  ) async {
    _currentReelsUserId = event.userId;
    _hasMoreReels = true;
    _lastReelsCreatedAt = null;
    _lastReelsId = null;
    emit(const PostsLoading());
    await _fetchReels(emit, isRefresh: true);
  }

  Future<void> _fetchReels(
    Emitter<PostsState> emit, {
    required bool isRefresh,
  }) async {
    final result = await getReelsUseCase(
      GetReelsParams(
        currentUserId: _currentReelsUserId!,
        pageSize: _pageSize,
        lastCreatedAt: _lastReelsCreatedAt,
        lastId: _lastReelsId,
      ),
    );
    result.fold(
      (failure) {
        final message = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get reels failed: $message');
        if (isRefresh) {
          emit(PostsError(message));
        } else {
          emit(
            ReelsLoadMoreError(
              message,
              currentPosts: state is ReelsLoaded
                  ? List<PostEntity>.from((state as ReelsLoaded).posts)
                  : [],
            ),
          );
        }
      },
      (newPosts) {
        List<PostEntity> updatedPosts;
        if (isRefresh) {
          updatedPosts = newPosts;
        } else {
          updatedPosts = state is ReelsLoaded
              ? List<PostEntity>.from((state as ReelsLoaded).posts)
              : <PostEntity>[];
          updatedPosts.addAll(newPosts);
        }
        if (newPosts.isNotEmpty) {
          _lastReelsCreatedAt = newPosts.last.createdAt;
          _lastReelsId = newPosts.last.id;
        }
        _hasMoreReels = newPosts.length == _pageSize;
        emit(
          ReelsLoaded(
            updatedPosts,
            hasMore: _hasMoreReels,
            isRealtimeActive: _isSubscribedToService,
          ),
        );
        AppLogger.info('Reels loaded with ${updatedPosts.length} posts');
      },
    );
  }

  Future<void> _onGetUserPosts(
    GetUserPostsEvent event,
    Emitter<PostsState> emit,
  ) async {
    AppLogger.info(
      'GetUserPostsEvent triggered for profileUserId: ${event.profileUserId} (currentUserId: ${event.currentUserId})',
    );
    _currentUserPostsProfileId = event.profileUserId;
    _currentUserPostsUserId = event.currentUserId;
    // CHANGE: Emit with profileUserId for isolation
    emit(UserPostsLoading(profileUserId: event.profileUserId));
    await _fetchUserPosts(
      emit,
      isRefresh: true,
      profileUserId: event.profileUserId,
    );
  }

  Future<void> _onLoadMoreUserPosts(
    LoadMoreUserPostsEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (_currentUserPostsProfileId == null ||
        !_hasMoreUserPosts ||
        state is UserPostsLoadingMore)
      return;
    // CHANGE: Emit with current profileUserId for consistency
    emit(UserPostsLoadingMore(profileUserId: _currentUserPostsProfileId));
    await _fetchUserPosts(
      emit,
      isRefresh: false,
      profileUserId: _currentUserPostsProfileId,
    );
  }

  Future<void> _onRefreshUserPosts(
    RefreshUserPostsEvent event,
    Emitter<PostsState> emit,
  ) async {
    _currentUserPostsProfileId = event.profileUserId;
    _currentUserPostsUserId = event.currentUserId;
    _hasMoreUserPosts = true;
    _lastUserPostsCreatedAt = null;
    _lastUserPostsId = null;
    // CHANGE: Emit with profileUserId for isolation
    emit(UserPostsLoading(profileUserId: event.profileUserId));
    await _fetchUserPosts(
      emit,
      isRefresh: true,
      profileUserId: event.profileUserId,
    );
  }

  Future<void> _fetchUserPosts(
    Emitter<PostsState> emit, {
    required bool isRefresh,
    required String? profileUserId, // NEW: Propagate for state
  }) async {
    AppLogger.info(
      'Fetching user posts for profileUserId: $profileUserId (isRefresh: $isRefresh)',
    );
    final result = await getUserPostsUseCase(
      GetUserPostsParams(
        profileUserId: _currentUserPostsProfileId!,
        currentUserId: _currentUserPostsUserId!,
        pageSize: _pageSize,
        lastCreatedAt: _lastUserPostsCreatedAt,
        lastId: _lastUserPostsId,
      ),
    );
    result.fold(
      (failure) {
        final message = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('Get user posts failed for $profileUserId: $message');
        if (isRefresh) {
          emit(UserPostsError(message, profileUserId: profileUserId));
        } else {
          emit(
            UserPostsLoadMoreError(
              message,
              currentPosts: state is UserPostsLoaded
                  ? List<PostEntity>.from((state as UserPostsLoaded).posts)
                  : [],
              profileUserId: profileUserId,
            ),
          );
        }
      },
      (newPosts) {
        List<PostEntity> updatedPosts;
        if (isRefresh) {
          updatedPosts = newPosts;
        } else {
          updatedPosts = state is UserPostsLoaded
              ? List<PostEntity>.from((state as UserPostsLoaded).posts)
              : <PostEntity>[];
          updatedPosts.addAll(newPosts);
        }
        if (newPosts.isNotEmpty) {
          _lastUserPostsCreatedAt = newPosts.last.createdAt;
          _lastUserPostsId = newPosts.last.id;
        }
        _hasMoreUserPosts = newPosts.length == _pageSize;
        // CHANGE: Emit with profileUserId for isolation
        emit(
          UserPostsLoaded(
            updatedPosts,
            hasMore: _hasMoreUserPosts,
            profileUserId: profileUserId,
          ),
        );
        AppLogger.info(
          'User posts loaded for $profileUserId with ${updatedPosts.length} posts',
        );
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
        AppLogger.error('Delete post failed: $friendlyMessage');
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
          final int newLikes = (p.likesCount + event.deltaLikes)
              .clamp(0, double.infinity)
              .toInt();
          final int newFavorites = (p.favoritesCount + event.deltaFavorites)
              .clamp(0, double.infinity)
              .toInt();
          final int newComments = (p.commentsCount + event.deltaComments)
              .clamp(0, double.infinity)
              .toInt();
          return p.copyWith(
            likesCount: newLikes,
            favoritesCount: newFavorites,
            commentsCount: newComments,
            isLiked: event.isLiked ?? p.isLiked,
            isFavorited: event.isFavorited ?? p.isFavorited,
          );
        }).toList();
      }

      if (currentState is FeedLoaded) {
        final updated = _apply(currentState.posts);
        emit(
          FeedLoaded(
            updated,
            hasMore: currentState.hasMore,
            isRealtimeActive: currentState.isRealtimeActive,
          ),
        );
        return;
      }
      if (currentState is ReelsLoaded) {
        final updated = _apply(currentState.posts);
        emit(
          ReelsLoaded(
            updated,
            hasMore: currentState.hasMore,
            isRealtimeActive: currentState.isRealtimeActive,
          ),
        );
        return;
      }
      if (currentState is UserPostsLoaded) {
        final updated = _apply(currentState.posts);
        // CHANGE: Preserve profileUserId in optimistic update
        emit(
          UserPostsLoaded(
            updated,
            hasMore: currentState.hasMore,
            profileUserId: currentState.profileUserId,
          ),
        );
        return;
      }
    } catch (e, st) {
      AppLogger.error(
        'Optimistic update failed in PostsBloc: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  // -------------------------
  // Real-time handlers
  // -------------------------
  Future<void> _onStartRealtimeListeners(
    StartRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (_isSubscribedToService) return;
    AppLogger.info('PostsBloc: subscribing to RealtimeService streams');
    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) => add(_RealtimePostReceivedEvent(post)),
    );
    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen((updateData) {
      int? safeParseInt(dynamic value) =>
          value is int ? value : int.tryParse(value.toString());
      add(
        _RealtimePostUpdatedEvent(
          postId: updateData['id'],
          likesCount: safeParseInt(updateData['likes_count']),
          commentsCount: safeParseInt(updateData['comments_count']),
          favoritesCount: safeParseInt(updateData['favorites_count']),
          sharesCount: safeParseInt(updateData['shares_count']),
        ),
      );
    });
    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) => add(_RealtimePostDeletedEvent(postId)),
    );
    _isSubscribedToService = true;
    // Update current state with realtime active
    _updateRealtimeStatus(emit);
  }

  Future<void> _onStopRealtimeListeners(
    StopRealtimeListenersEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (!_isSubscribedToService) return;
    AppLogger.info('PostsBloc: unsubscribing from RealtimeService streams');
    await _realtimeNewPostSub?.cancel();
    await _realtimePostUpdateSub?.cancel();
    await _realtimePostDeletedSub?.cancel();
    _realtimeNewPostSub = null;
    _realtimePostUpdateSub = null;
    _realtimePostDeletedSub = null;
    _isSubscribedToService = false;
    _updateRealtimeStatus(emit);
  }

  void _updateRealtimeStatus(Emitter<PostsState> emit) {
    final active = _isSubscribedToService;
    final state = this.state;
    if (state is FeedLoaded)
      emit(
        FeedLoaded(
          state.posts,
          hasMore: state.hasMore,
          isRealtimeActive: active,
        ),
      );
    if (state is ReelsLoaded)
      emit(
        ReelsLoaded(
          state.posts,
          hasMore: state.hasMore,
          isRealtimeActive: active,
        ),
      );
    // CHANGE: Preserve profileUserId in realtime status update
    if (state is UserPostsLoaded)
      emit(
        UserPostsLoaded(
          state.posts,
          hasMore: state.hasMore,
          profileUserId: state.profileUserId,
        ),
      );
  }

  Future<void> _onRealtimePostReceived(
    _RealtimePostReceivedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final state = this.state;
    final post = event.post;
    bool added = false;
    if (state is FeedLoaded && !state.posts.any((p) => p.id == post.id)) {
      final updated = [post, ...state.posts];
      emit(
        FeedLoaded(
          updated,
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
      added = true;
    }
    if (state is ReelsLoaded &&
        post.mediaType == 'video' &&
        !state.posts.any((p) => p.id == post.id)) {
      final updated = [post, ...state.posts];
      emit(
        ReelsLoaded(
          updated,
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
      added = true;
    }
    if (added) AppLogger.info('New post added realtime: ${post.id}');
  }

  Future<void> _onRealtimePostUpdated(
    _RealtimePostUpdatedEvent event,
    Emitter<PostsState> emit,
  ) async {
    // Changed to Future<void>
    final state = this.state;
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

    if (state is FeedLoaded)
      emit(
        FeedLoaded(
          _applyUpdate(state.posts),
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
    if (state is ReelsLoaded)
      emit(
        ReelsLoaded(
          _applyUpdate(state.posts),
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
    if (state is UserPostsLoaded) {
      // CHANGE: Preserve profileUserId in realtime update
      emit(
        UserPostsLoaded(
          _applyUpdate(state.posts),
          hasMore: state.hasMore,
          profileUserId: state.profileUserId,
        ),
      );
    }
    emit(
      RealtimePostUpdate(
        // Use named parameters
        postId: event.postId,
        likesCount: event.likesCount,
        commentsCount: event.commentsCount,
        favoritesCount: event.favoritesCount,
        sharesCount: event.sharesCount,
      ),
    );
    AppLogger.info('Post updated realtime: ${event.postId}');
  }

  void _onRealtimePostDeleted(
    _RealtimePostDeletedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final state = this.state;
    if (state is FeedLoaded) {
      final updated = state.posts.where((p) => p.id != event.postId).toList();
      emit(
        FeedLoaded(
          updated,
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
    }
    if (state is ReelsLoaded) {
      final updated = state.posts.where((p) => p.id != event.postId).toList();
      emit(
        ReelsLoaded(
          updated,
          hasMore: state.hasMore,
          isRealtimeActive: state.isRealtimeActive,
        ),
      );
    }
    if (state is UserPostsLoaded) {
      // CHANGE: Preserve profileUserId in realtime deletion
      final updated = state.posts.where((p) => p.id != event.postId).toList();
      emit(
        UserPostsLoaded(
          updated,
          hasMore: state.hasMore,
          profileUserId: state.profileUserId,
        ),
      );
    }
    AppLogger.info('Post deleted realtime: ${event.postId}');
  }

  @override
  Future<void> close() async {
    AppLogger.info('Closing PostsBloc - cancelling realtime subscriptions');
    await _realtimeNewPostSub?.cancel();
    await _realtimePostUpdateSub?.cancel();
    await _realtimePostDeletedSub?.cancel();
    return super.close();
  }
}
