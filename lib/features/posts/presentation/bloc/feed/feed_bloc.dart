import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_feed_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeedUseCase getFeedUseCase;
  final RealtimeService realtimeService;

  StreamSubscription<PostEntity>? _realtimeNewPostSub;
  StreamSubscription<Map<String, dynamic>>? _realtimePostUpdateSub;
  StreamSubscription<String>? _realtimePostDeletedSub;
  bool _isSubscribedToService = false;

  static const int _pageSize = 20;
  bool _hasMoreFeed = true;
  DateTime? _lastFeedCreatedAt;
  String? _lastFeedId;
  String? _currentFeedUserId;
  bool _isFetchingFeed = false;

  FeedBloc({required this.getFeedUseCase, required this.realtimeService})
    : super(const FeedInitial()) {
    // List handlers
    on<GetFeedEvent>(_onGetFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
    on<RefreshFeedEvent>(_onRefreshFeed);

    // Realtime handlers
    on<StartFeedRealtime>(_onStartFeedRealtime);
    on<StopFeedRealtime>(_onStopFeedRealtime);
    on<_RealtimeFeedPostReceived>(_onRealtimePostReceived);
    on<_RealtimeFeedPostUpdated>(_onRealtimePostUpdated);
    on<_RealtimeFeedPostDeleted>(_onRealtimePostDeleted);

    // Local update handlers
    on<UpdateFeedPostOptimistic>(_onUpdateFeedPostOptimistic);
    on<AddPostToFeed>(_onAddPostToFeed);
    on<RemovePostFromFeed>(_onRemovePostFromFeed);
  }

  Future<void> _onGetFeed(GetFeedEvent event, Emitter<FeedState> emit) async {
    AppLogger.info('GetFeedEvent triggered');
    _currentFeedUserId = event.userId;
    emit(const FeedLoading());
    await _safeFetchFeed(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreFeed(
    LoadMoreFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (_currentFeedUserId == null || !_hasMoreFeed || _isFetchingFeed) {
      return;
    }

    final currentPostsSnapshot = state is FeedLoaded
        ? (state as FeedLoaded).posts
        : <PostEntity>[];

    emit(FeedLoadingMore(currentPosts: currentPostsSnapshot));
    await _safeFetchFeed(
      emit,
      isRefresh: false,
      existingPosts: currentPostsSnapshot,
    );
  }

  Future<void> _onRefreshFeed(
    RefreshFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    _currentFeedUserId = event.userId;
    _hasMoreFeed = true;
    _lastFeedCreatedAt = null;
    _lastFeedId = null;
    emit(const FeedLoading());
    await _safeFetchFeed(emit, isRefresh: true);
  }

  Future<void> _safeFetchFeed(
    Emitter<FeedState> emit, {
    required bool isRefresh,
    List<PostEntity>? existingPosts,
  }) async {
    if (_isFetchingFeed) return;
    _isFetchingFeed = true;
    try {
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
            emit(FeedError(message));
          } else {
            final currentPosts = existingPosts ?? [];
            emit(FeedLoadMoreError(message, currentPosts: currentPosts));
          }
        },
        (newPosts) {
          List<PostEntity> updatedPosts;
          if (isRefresh) {
            updatedPosts = newPosts;
          } else {
            updatedPosts = List<PostEntity>.from(existingPosts ?? []);
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
    } finally {
      _isFetchingFeed = false;
    }
  }

  Future<void> _onUpdateFeedPostOptimistic(
    UpdateFeedPostOptimistic event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

    final updatedPosts = currentState.posts.map((p) {
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

    emit(currentState.copyWith(posts: updatedPosts));
  }

  Future<void> _onAddPostToFeed(
    AddPostToFeed event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is FeedLoaded) {
      final updatedPosts = [event.post, ...currentState.posts];
      emit(currentState.copyWith(posts: updatedPosts));
    }
  }

  Future<void> _onRemovePostFromFeed(
    RemovePostFromFeed event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is FeedLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
    }
  }

  Future<void> _onStartFeedRealtime(
    StartFeedRealtime event,
    Emitter<FeedState> emit,
  ) async {
    if (_isSubscribedToService) return;
    AppLogger.info('FeedBloc: subscribing to RealtimeService');
    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) => add(_RealtimeFeedPostReceived(post)),
    );
    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen((updateData) {
      int? safeParseInt(dynamic value) =>
          value is int ? value : int.tryParse(value.toString());
      add(
        _RealtimeFeedPostUpdated(
          postId: updateData['id'],
          likesCount: safeParseInt(updateData['likes_count']),
          commentsCount: safeParseInt(updateData['comments_count']),
          favoritesCount: safeParseInt(updateData['favorites_count']),
          sharesCount: safeParseInt(updateData['shares_count']),
        ),
      );
    });
    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) => add(_RealtimeFeedPostDeleted(postId)),
    );
    _isSubscribedToService = true;
    if (state is FeedLoaded) {
      emit((state as FeedLoaded).copyWith(isRealtimeActive: true));
    }
  }

  Future<void> _onStopFeedRealtime(
    StopFeedRealtime event,
    Emitter<FeedState> emit,
  ) async {
    if (!_isSubscribedToService) return;
    AppLogger.info('FeedBloc: unsubscribing from RealtimeService');
    await _realtimeNewPostSub?.cancel();
    await _realtimePostUpdateSub?.cancel();
    await _realtimePostDeletedSub?.cancel();
    _isSubscribedToService = false;
    if (state is FeedLoaded) {
      emit((state as FeedLoaded).copyWith(isRealtimeActive: false));
    }
  }

  Future<void> _onRealtimePostReceived(
    _RealtimeFeedPostReceived event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is FeedLoaded &&
        !currentState.posts.any((p) => p.id == event.post.id)) {
      final updatedPosts = [event.post, ...currentState.posts];
      emit(currentState.copyWith(posts: updatedPosts));
      AppLogger.info('New post added to feed realtime: ${event.post.id}');
    }
  }

  Future<void> _onRealtimePostUpdated(
    _RealtimeFeedPostUpdated event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

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

    emit(currentState.copyWith(posts: updatedPosts));
  }

  void _onRealtimePostDeleted(
    _RealtimeFeedPostDeleted event,
    Emitter<FeedState> emit,
  ) {
    final currentState = state;
    if (currentState is FeedLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
      AppLogger.info('Post removed from feed realtime: ${event.postId}');
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing FeedBloc - cancelling realtime subscriptions');
    _realtimeNewPostSub?.cancel();
    _realtimePostUpdateSub?.cancel();
    _realtimePostDeletedSub?.cancel();
    return super.close();
  }
}
