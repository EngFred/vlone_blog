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

  // Realtime subscriptions (filtered by profile id inside handlers)
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

  // ---- existing fetch handlers (unchanged) ----
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

    final currentPostsSnapshot = state is UserPostsLoaded
        ? (state as UserPostsLoaded).posts
        : <PostEntity>[];

    emit(
      UserPostsLoadingMore(
        currentPosts: currentPostsSnapshot,
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
                currentPosts: currentPosts,
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
              hasMore: _hasMoreUserPosts,
              profileUserId: profileId,
            ),
          );
        },
      );
    } finally {
      _isFetchingUserPosts = false;
    }
  }

  Future<void> _onRemovePostFromUserPosts(
    RemovePostFromUserPosts event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentState = state;
    if (currentState is UserPostsLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
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

    // new posts (filter by post.author/user id)
    _realtimeNewPostSub = realtimeService.onNewPost.listen(
      (post) {
        try {
          if (post.userId == profileId) {
            add(_RealtimeUserPostReceived(post));
          }
        } catch (e) {
          AppLogger.error('UserPosts new post listener error: $e', error: e);
        }
      },
      onError: (err) {
        AppLogger.error('UserPosts new post stream error: $err', error: err);
      },
    );

    // post updates (counts). The service provides update data map; we must check if the post exists locally or belongs to this profile.
    _realtimePostUpdateSub = realtimeService.onPostUpdate.listen(
      (updateData) {
        try {
          final postId = updateData['id']?.toString();
          if (postId == null) return;

          final currentState = state;
          bool relevant = false;

          if (currentState is UserPostsLoaded) {
            // Safely try to find the post in current list — avoid PostEntity.empty()
            try {
              final maybe = currentState.posts.firstWhere(
                (p) => p.id == postId,
              );
              if (maybe.userId == profileId) {
                relevant = true;
              }
            } catch (_) {
              // not present in the list -> not relevant for this profile's currently loaded set
            }
          }

          if (relevant) {
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
        } catch (e) {
          AppLogger.error('UserPosts post update listener error: $e', error: e);
        }
      },
      onError: (err) {
        AppLogger.error('UserPosts post update stream error: $err', error: err);
      },
    );

    // post deletions
    _realtimePostDeletedSub = realtimeService.onPostDeleted.listen(
      (postId) {
        try {
          // If the post belongs to this profile in current state, trigger removal.
          final currentState = state;
          if (currentState is UserPostsLoaded &&
              currentState.posts.any((p) => p.id == postId)) {
            add(_RealtimeUserPostDeleted(postId));
          }
        } catch (e) {
          AppLogger.error(
            'UserPosts post deleted listener error: $e',
            error: e,
          );
        }
      },
      onError: (err) {
        AppLogger.error(
          'UserPosts post deleted stream error: $err',
          error: err,
        );
      },
    );

    _isSubscribedToService = true;

    // If already loaded state, re-emit with realtime active flag if your state supports it
    if (state is UserPostsLoaded) {
      emit(
        (state as UserPostsLoaded).copyWith(
          isRealtimeActive: _isSubscribedToService,
        ),
      );
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

    if (state is UserPostsLoaded) {
      emit(
        (state as UserPostsLoaded).copyWith(
          isRealtimeActive: _isSubscribedToService,
        ),
      );
    }
  }

  Future<void> _onRealtimeUserPostReceived(
    _RealtimeUserPostReceived event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentState = state;
    // If the post is already present, ignore
    if (currentState is UserPostsLoaded &&
        !currentState.posts.any((p) => p.id == event.post.id)) {
      final updatedPosts = [event.post, ...currentState.posts];
      emit(currentState.copyWith(posts: updatedPosts));
      AppLogger.info('New post added to user posts realtime: ${event.post.id}');
    }
  }

  Future<void> _onRealtimeUserPostUpdated(
    _RealtimeUserPostUpdated event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! UserPostsLoaded) return;

    final updatedPosts = currentState.posts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(
          likesCount: event.likesCount ?? post.likesCount,
          commentsCount: event.commentsCount ?? post.commentsCount,
          favoritesCount: event.favoritesCount ?? post.favoritesCount,
        );
      }
      return post;
    }).toList();

    emit(currentState.copyWith(posts: updatedPosts));
  }

  Future<void> _onRealtimeUserPostDeleted(
    _RealtimeUserPostDeleted event,
    Emitter<UserPostsState> emit,
  ) async {
    final currentState = state;
    if (currentState is UserPostsLoaded) {
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
      AppLogger.info('User post removed realtime: ${event.postId}');
    }
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
