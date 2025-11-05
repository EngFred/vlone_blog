import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_reels_usecase.dart';
part 'reels_event.dart';
part 'reels_state.dart';

class ReelsBloc extends Bloc<ReelsEvent, ReelsState> {
  final GetReelsUseCase getReelsUseCase;
  final RealtimeService realtimeService;

  StreamSubscription<PostEntity>? _realtimeNewPostSub;
  StreamSubscription<Map<String, dynamic>>? _realtimePostUpdateSub;
  StreamSubscription<String>? _realtimePostDeletedSub;
  bool _isSubscribedToService = false;

  static const int _pageSize = 20;
  bool _hasMoreReels = true;
  DateTime? _lastReelsCreatedAt;
  String? _lastReelsId;
  String? _currentReelsUserId;
  bool _isFetchingReels = false;

  ReelsBloc({required this.getReelsUseCase, required this.realtimeService})
    : super(const ReelsInitial()) {
    on<GetReelsEvent>(_onGetReels);
    on<LoadMoreReelsEvent>(_onLoadMoreReels);
    on<RefreshReelsEvent>(_onRefreshReels); // UPDATED

    on<StartReelsRealtime>(_onStartReelsRealtime);
    on<StopReelsRealtime>(_onStopReelsRealtime);
    on<_RealtimeReelsPostReceived>(_onRealtimePostReceived);
    on<_RealtimeReelsPostDeleted>(_onRealtimePostDeleted);
    on<_RealtimeReelsPostUpdated>(_onRealtimeReelsPostUpdated);

    on<RemovePostFromReels>(_onRemovePostFromReels);
  }

  Future<void> _onGetReels(
    GetReelsEvent event,
    Emitter<ReelsState> emit,
  ) async {
    AppLogger.info('GetReelsEvent triggered');
    _currentReelsUserId = event.userId;
    emit(const ReelsLoading());
    await _safeFetchReels(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreReels(
    LoadMoreReelsEvent event,
    Emitter<ReelsState> emit,
  ) async {
    if (_currentReelsUserId == null || !_hasMoreReels || _isFetchingReels) {
      return;
    }

    final currentPostsSnapshot = getPostsFromState(
      state,
    ); // Using public getter

    // Use 'posts' for consistent state
    emit(ReelsLoadingMore(posts: currentPostsSnapshot));
    await _safeFetchReels(
      emit,
      isRefresh: false,
      existingPosts: currentPostsSnapshot,
    );
  }

  Future<void> _onRefreshReels(
    RefreshReelsEvent event,
    Emitter<ReelsState> emit,
  ) async {
    _currentReelsUserId = event.userId;
    _hasMoreReels = true;
    _lastReelsCreatedAt = null;
    _lastReelsId = null;
    // Do not emit ReelsLoading, let the RefreshIndicator spin
    await _safeFetchReels(
      emit,
      isRefresh: true,
      refreshCompleter: event.refreshCompleter, // PASS COMPLETER
    );
  }

  Future<void> _safeFetchReels(
    Emitter<ReelsState> emit, {
    required bool isRefresh,
    List<PostEntity>? existingPosts,
    // ADDED: Optional completer for refresh indicator
    Completer<void>? refreshCompleter,
  }) async {
    if (_isFetchingReels) return;
    _isFetchingReels = true;
    try {
      final result = await getReelsUseCase(
        GetReelsParams(
          currentUserId: _currentReelsUserId!,
          pageSize: _pageSize,
          lastCreatedAt: isRefresh ? null : _lastReelsCreatedAt,
          lastId: isRefresh ? null : _lastReelsId,
        ),
      );

      result.fold(
        (failure) {
          final message = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('Get reels failed: $message');
          if (isRefresh) {
            // Emit ReelsError with the completer
            emit(ReelsError(message, refreshCompleter: refreshCompleter));
          } else {
            final currentPosts = existingPosts ?? [];
            emit(ReelsLoadMoreError(message, posts: currentPosts));
          }
          refreshCompleter?.complete(); // COMPLETE ON ERROR
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
            _lastReelsCreatedAt = newPosts.last.createdAt;
            _lastReelsId = newPosts.last.id;
          }
          _hasMoreReels = newPosts.length == _pageSize;

          emit(
            ReelsLoaded(
              updatedPosts,
              hasMore: _hasMoreReels,
              isRealtimeActive: _isSubscribedToService,
              refreshCompleter: refreshCompleter, // PASS COMPLETER
            ),
          );
          AppLogger.info('Reels loaded with ${updatedPosts.length} posts');
          refreshCompleter?.complete(); // COMPLETE ON SUCCESS
        },
      );
    } finally {
      _isFetchingReels = false;
    }
  }

  Future<void> _onRemovePostFromReels(
    RemovePostFromReels event,
    Emitter<ReelsState> emit,
  ) async {
    final currentState = state;
    if (currentState is ReelsLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
    } else if (currentState is ReelsLoadingMore) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(ReelsLoadingMore(posts: updatedPosts));
    } else if (currentState is ReelsLoadMoreError) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(ReelsLoadMoreError(currentState.message, posts: updatedPosts));
    }
  }

  // --- Realtime Handlers ---

  Future<void> _onStartReelsRealtime(
    StartReelsRealtime event,
    Emitter<ReelsState> emit,
  ) async {
    if (_isSubscribedToService) return;
    AppLogger.info('ReelsBloc: subscribing to RealtimeService');
    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) => add(_RealtimeReelsPostReceived(post)),
    );
    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen((updateData) {
      int? safeParseInt(dynamic value) =>
          value is int ? value : int.tryParse(value.toString());
      add(
        _RealtimeReelsPostUpdated(
          postId: updateData['id'],
          likesCount: safeParseInt(updateData['likes_count']),
          commentsCount: safeParseInt(updateData['comments_count']),
          favoritesCount: safeParseInt(updateData['favorites_count']),
          sharesCount: safeParseInt(updateData['shares_count']),
        ),
      );
    });
    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) => add(_RealtimeReelsPostDeleted(postId)),
    );
    _isSubscribedToService = true;
    if (state is ReelsLoaded) {
      emit((state as ReelsLoaded).copyWith(isRealtimeActive: true));
    }
  }

  Future<void> _onStopReelsRealtime(
    StopReelsRealtime event,
    Emitter<ReelsState> emit,
  ) async {
    if (!_isSubscribedToService) return;
    AppLogger.info('ReelsBloc: unsubscribing from RealtimeService');
    await _realtimeNewPostSub?.cancel();
    await _realtimePostUpdateSub?.cancel();
    await _realtimePostDeletedSub?.cancel();
    _isSubscribedToService = false;
    if (state is ReelsLoaded) {
      emit((state as ReelsLoaded).copyWith(isRealtimeActive: false));
    }
  }

  Future<void> _onRealtimePostReceived(
    _RealtimeReelsPostReceived event,
    Emitter<ReelsState> emit,
  ) async {
    final currentState = state;
    // Only add if it's a video (reel) and not already in the list
    if (currentState is ReelsLoaded &&
        event.post.mediaType == 'video' &&
        !currentState.posts.any((p) => p.id == event.post.id)) {
      final updatedPosts = [event.post, ...currentState.posts];
      emit(currentState.copyWith(posts: updatedPosts));
      AppLogger.info('New reel added realtime: ${event.post.id}');
    }
  }

  void _onRealtimePostDeleted(
    _RealtimeReelsPostDeleted event,
    Emitter<ReelsState> emit,
  ) {
    // This logic is now robust and handles all states
    add(RemovePostFromReels(event.postId));
  }

  // MADE PUBLIC: Renamed from _getPostsFromState to getPostsFromState
  List<PostEntity> getPostsFromState(ReelsState state) {
    if (state is ReelsLoaded) {
      return state.posts;
    } else if (state is ReelsLoadingMore) {
      return state.posts;
    } else if (state is ReelsLoadMoreError) {
      return state.posts;
    }
    return [];
  }

  void _emitUpdatedState(
    Emitter<ReelsState> emit,
    List<PostEntity> updatedPosts,
  ) {
    final currentState = state;
    if (currentState is ReelsLoaded) {
      emit(currentState.copyWith(posts: updatedPosts));
    } else if (currentState is ReelsLoadingMore) {
      emit(ReelsLoadingMore(posts: updatedPosts));
    } else if (currentState is ReelsLoadMoreError) {
      emit(ReelsLoadMoreError(currentState.message, posts: updatedPosts));
    }
  }

  Future<void> _onRealtimeReelsPostUpdated(
    _RealtimeReelsPostUpdated event,
    Emitter<ReelsState> emit,
  ) async {
    final currentPosts = getPostsFromState(state);
    if (currentPosts.isEmpty) return;

    final updatedPosts = currentPosts.map((post) {
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

    _emitUpdatedState(emit, updatedPosts);
    AppLogger.info('Realtime post updated in reels: ${event.postId}');
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing ReelsBloc - cancelling realtime subscriptions');
    _realtimeNewPostSub?.cancel();
    _realtimePostUpdateSub?.cancel();
    _realtimePostDeletedSub?.cancel();
    return super.close();
  }
}
