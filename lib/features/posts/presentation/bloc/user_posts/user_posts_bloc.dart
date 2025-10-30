import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/usecases/get_user_posts_usecase.dart';

part 'user_posts_event.dart';
part 'user_posts_state.dart';

class UserPostsBloc extends Bloc<UserPostsEvent, UserPostsState> {
  final GetUserPostsUseCase getUserPostsUseCase;
  // You can inject RealtimeService here if you want live updates on profiles
  // final RealtimeService realtimeService;

  static const int _pageSize = 20;
  bool _hasMoreUserPosts = true;
  DateTime? _lastUserPostsCreatedAt;
  String? _lastUserPostsId;
  String? _currentUserPostsProfileId;
  String? _currentUserPostsUserId;
  bool _isFetchingUserPosts = false;

  UserPostsBloc({
    required this.getUserPostsUseCase,
    // required this.realtimeService,
  }) : super(const UserPostsInitial()) {
    on<GetUserPostsEvent>(_onGetUserPosts);
    on<LoadMoreUserPostsEvent>(_onLoadMoreUserPosts);
    on<RefreshUserPostsEvent>(_onRefreshUserPosts);
    on<RemovePostFromUserPosts>(_onRemovePostFromUserPosts);
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

    // Ensure we have a profile ID to fetch for
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
}
