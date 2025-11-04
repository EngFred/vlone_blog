import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';

part 'user_posts_event.dart';
part 'user_posts_state.dart';

class UserPostsBloc extends Bloc<UserPostsEvent, UserPostsState> {
  final GetUserPostsUseCase getUserPostsUseCase;
  final RealtimeService realtimeService;

  StreamSubscription<PostEntity>? _realtimeNewPostSub;
  StreamSubscription<Map<String, dynamic>>? _realtimePostUpdateSub;
  StreamSubscription<String>? _realtimePostDeletedSub;
  bool _isSubscribedToService = false;

  static const int _pageSize = 20;
  bool _hasMoreUserPosts = true;
  DateTime? _lastUserPostsCreatedAt;
  String? _lastUserPostsId;
  String? _currentUserPostsProfileId;
  String? _currentUserPostsUserId;
  bool _isFetchingUserPosts = false;

  UserPostsBloc({
    required this.getUserPostsUseCase,
    required this.realtimeService,
  }) : super(const UserPostsInitial()) {
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<LoadMoreUserPostsEvent>(_onLoadMoreUserPosts);
    on<RefreshUserPostsEvent>(_onRefreshUserPosts);
    on<RemovePostFromUserPosts>(_onRemovePostFromUserPosts);

    // Realtime control events
    on<StartUserPostsRealtime>(_onStartUserPostsRealtime);
    on<StopUserPostsRealtime>(_onStopUserPostsRealtime);

    // Internal realtime events
    on<_RealtimeUserPostReceived>(_onRealtimeUserPostReceived);
    on<_RealtimeUserPostUpdated>(_onRealtimeUserPostUpdated);
    on<_RealtimeUserPostDeleted>(_onRealtimeUserPostDeleted);
  }

  Future<void> _onGetUserPosts(
    GetUserPostsEvent event,
    Emitter<UserPostsState> emit,
  ) async {
    _currentUserPostsProfileId = event.profileUserId;
    _currentUserPostsUserId = event.currentUserId;
    emit(UserPostsLoading(profileUserId: event.profileUserId));
    await _safeFetchUserPosts(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreUserPosts(
    LoadMoreUserPostsEvent event,
    Emitter<UserPostsState> emit,
  ) async {
    if (_currentUserPostsProfileId == null ||
        !_hasMoreUserPosts ||
        _isFetchingUserPosts) {
      return;
    }

    // Get posts from *any* state that has them
    final currentPostsSnapshot = _getPostsFromState(state);

    emit(
      UserPostsLoadingMore(
        posts: currentPostsSnapshot,
        profileUserId: _currentUserPostsProfileId!,
      ),
    );
    await _safeFetchUserPosts(
      emit,
      isRefresh: false,
      existingPosts: currentPostsSnapshot,
    );
  }

  Future<void> _onRefreshUserPosts(
    RefreshUserPostsEvent event,
    Emitter<UserPostsState> emit,
  ) async {
    _currentUserPostsProfileId = event.profileUserId;
    _currentUserPostsUserId = event.currentUserId;
    _hasMoreUserPosts = true;
    _lastUserPostsCreatedAt = null;
    _lastUserPostsId = null;
    emit(UserPostsLoading(profileUserId: event.profileUserId));
    await _safeFetchUserPosts(emit, isRefresh: true);
  }

  Future<void> _safeFetchUserPosts(
    Emitter<UserPostsState> emit, {
    required bool isRefresh,
    List<PostEntity>? existingPosts,
  }) async {
    if (_isFetchingUserPosts) return;
    _isFetchingUserPosts = true;

    final profileId = _currentUserPostsProfileId;
    if (profileId == null) {
      emit(const UserPostsError("Profile ID not set.", profileUserId: null));
      _isFetchingUserPosts = false;
      return;
    }

    try {
      final result = await getUserPostsUseCase(
        GetUserPostsParams(
          profileUserId: profileId,
          currentUserId: _currentUserPostsUserId!,
          pageSize: _pageSize,
          lastCreatedAt: _lastUserPostsCreatedAt,
          lastId: _lastUserPostsId,
        ),
      );

      result.fold(
        (failure) {
          final message = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('Get user posts failed for $profileId: $message');
          if (isRefresh) {
            emit(UserPostsError(message, profileUserId: profileId));
          } else {
            final currentPosts = existingPosts ?? [];
            emit(
              UserPostsLoadMoreError(
                message,
                posts: currentPosts,
                profileUserId: profileId,
              ),
            );
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
            _lastUserPostsCreatedAt = newPosts.last.createdAt;
            _lastUserPostsId = newPosts.last.id;
          }
          _hasMoreUserPosts = newPosts.length == _pageSize;

          emit(
            UserPostsLoaded(
              updatedPosts,
              profileUserId: profileId,
              hasMore: _hasMoreUserPosts,
              isRealtimeActive: _isSubscribedToService,
            ),
          );
        },
      );
    } finally {
      _isFetchingUserPosts = false;
    }
  }

  // Helper to get posts from any state
  List<PostEntity> _getPostsFromState(UserPostsState state) {
    if (state is UserPostsLoaded) {
      return state.posts;
    } else if (state is UserPostsLoadingMore) {
      return state.posts;
    } else if (state is UserPostsLoadMoreError) {
      return state.posts;
    }
    return [];
  }

  // Helper to emit the correct state class
  void _emitUpdatedState(
    Emitter<UserPostsState> emit,
    List<PostEntity> updatedPosts,
  ) {
    final currentState = state;
    if (currentState is UserPostsLoaded) {
      emit(currentState.copyWith(posts: updatedPosts));
    } else if (currentState is UserPostsLoadingMore) {
      emit(
        UserPostsLoadingMore(
          posts: updatedPosts,
          profileUserId: currentState.profileUserId!,
        ),
      );
    } else if (currentState is UserPostsLoadMoreError) {
      emit(
        UserPostsLoadMoreError(
          currentState.message,
          posts: updatedPosts,
          profileUserId: currentState.profileUserId!,
        ),
      );
    }
  }

  Future<void> _onRemovePostFromUserPosts(
    RemovePostFromUserPosts event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentPosts = _getPostsFromState(state);
    if (currentPosts.isEmpty) return;

    final updatedPosts = currentPosts
        .where((p) => p.id != event.postId)
        .toList();

    // Only emit if a change actually happened
    if (updatedPosts.length < currentPosts.length) {
      _emitUpdatedState(emit, updatedPosts);
    }
  }

  // ---- Realtime handlers ----

  Future<void> _onStartUserPostsRealtime(
    StartUserPostsRealtime event,
    Emitter<UserPostsState> emit,
  ) async {
    if (_isSubscribedToService) return;
    AppLogger.info(
      'UserPostsBloc: subscribing to RealtimeService for profile ${event.profileUserId}',
    );

    final profileId = event.profileUserId;
    _currentUserPostsProfileId = profileId; // Ensure this is set

    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) {
        if (post.userId == _currentUserPostsProfileId) {
          add(_RealtimeUserPostReceived(post));
        }
      },
      onError: (err) =>
          AppLogger.error('UserPosts new post stream error: $err', error: err),
    );

    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen(
      (updateData) {
        final postId = updateData['id']?.toString();
        if (postId == null) return;

        // Check if the post is relevant before dispatching
        final currentPosts = _getPostsFromState(state);
        final post = currentPosts.firstWhere(
          (p) => p.id == postId,
          orElse: () => PostEntity.empty,
        );

        if (post.id.isNotEmpty && post.userId == _currentUserPostsProfileId) {
          int? safeParseInt(dynamic v) =>
              v is int ? v : int.tryParse(v?.toString() ?? '');
          add(
            _RealtimeUserPostUpdated(
              postId: postId,
              likesCount: safeParseInt(updateData['likes_count']),
              commentsCount: safeParseInt(updateData['comments_count']),
              favoritesCount: safeParseInt(updateData['favorites_count']),
            ),
          );
        }
      },
      onError: (err) => AppLogger.error(
        'UserPosts post update stream error: $err',
        error: err,
      ),
    );

    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) {
        // Check if the post is in our current state before dispatching
        final currentPosts = _getPostsFromState(state);
        if (currentPosts.any((p) => p.id == postId)) {
          add(_RealtimeUserPostDeleted(postId));
        }
      },
      onError: (err) => AppLogger.error(
        'UserPosts post deleted stream error: $err',
        error: err,
      ),
    );

    _isSubscribedToService = true;

    if (state is UserPostsLoaded) {
      emit((state as UserPostsLoaded).copyWith(isRealtimeActive: true));
    }
  }

  Future<void> _onStopUserPostsRealtime(
    StopUserPostsRealtime event,
    Emitter<UserPostsState> emit,
  ) async {
    if (!_isSubscribedToService) return;
    AppLogger.info('UserPostsBloc: unsubscribing from RealtimeService');
    await _realtimeNewPostSub?.cancel();
    await _realtimePostUpdateSub?.cancel();
    await _realtimePostDeletedSub?.cancel();
    _realtimeNewPostSub = null;
    _realtimePostUpdateSub = null;
    _realtimePostDeletedSub = null;
    _isSubscribedToService = false;
    _currentUserPostsProfileId = null; // Clear profile ID on stop

    if (state is UserPostsLoaded) {
      emit((state as UserPostsLoaded).copyWith(isRealtimeActive: false));
    }
  }

  Future<void> _onRealtimeUserPostReceived(
    _RealtimeUserPostReceived event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentPosts = _getPostsFromState(state);

    if (!currentPosts.any((p) => p.id == event.post.id)) {
      final updatedPosts = [event.post, ...currentPosts];
      _emitUpdatedState(emit, updatedPosts);
      AppLogger.info('New post added to user posts realtime: ${event.post.id}');
    }
  }

  Future<void> _onRealtimeUserPostUpdated(
    _RealtimeUserPostUpdated event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentPosts = _getPostsFromState(state);
    if (currentPosts.isEmpty) return;

    final updatedPosts = currentPosts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(
          likesCount: event.likesCount ?? post.likesCount,
          commentsCount: event.commentsCount ?? post.commentsCount,
          favoritesCount: event.favoritesCount ?? post.favoritesCount,
        );
      }
      return post;
    }).toList();

    _emitUpdatedState(emit, updatedPosts);
  }

  Future<void> _onRealtimeUserPostDeleted(
    _RealtimeUserPostDeleted event,
    Emitter<UserPostsState> emit,
  ) async {
    // This just points to the robust handler
    add(RemovePostFromUserPosts(event.postId));
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing UserPostsBloc - cancelling realtime subscriptions');
    _realtimeNewPostSub?.cancel();
    _realtimePostUpdateSub?.cancel();
    _realtimePostDeletedSub?.cancel();
    return super.close();
  }
}
