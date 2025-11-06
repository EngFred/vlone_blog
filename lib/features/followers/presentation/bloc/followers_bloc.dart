import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_follow_status_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

part 'followers_event.dart';
part 'followers_state.dart';

class FollowersBloc extends Bloc<FollowersEvent, FollowersState> {
  final FollowUserUseCase followUserUseCase;
  final GetFollowersUseCase getFollowersUseCase;
  final GetFollowingUseCase getFollowingUseCase;
  final GetFollowStatusUseCase getFollowStatusUseCase;

  static const int defaultPageSize = 20;

  /// Tracks follow/unfollow operations currently in flight by target user id.
  final Set<String> _processingFollowIds = {};

  FollowersBloc({
    required this.followUserUseCase,
    required this.getFollowersUseCase,
    required this.getFollowingUseCase,
    required this.getFollowStatusUseCase,
  }) : super(const FollowersInitial()) {
    on<FollowUserEvent>(_onFollowUser);
    on<GetFollowersEvent>(_onGetFollowers);
    on<GetFollowingEvent>(_onGetFollowing);
    on<GetFollowStatusEvent>(_onGetFollowStatus);
  }

  Future<void> _onFollowUser(
    FollowUserEvent event,
    Emitter<FollowersState> emit,
  ) async {
    // Guard duplicate requests to same target user.
    if (_processingFollowIds.contains(event.followingId)) {
      // ignore duplicate follow/unfollow for same user while an op is in flight
      return;
    }
    _processingFollowIds.add(event.followingId);

    // Preserving current list/context so we can update it and never lose the list UI.
    final current = state;
    List<UserListEntity> currentUsers = [];
    bool currentHasMore = true;

    if (current is FollowersLoaded) {
      currentUsers = current.users;
      currentHasMore = current.hasMore;
    } else if (current is FollowersLoadingMore) {
      currentUsers = current.users;
    } else if (current is FollowersLoadMoreError) {
      currentUsers = current.users;
    } else if (current is UserFollowed) {
      currentUsers = current.users;
      currentHasMore = current.hasMore;
    } else if (current is FollowOperationFailed) {
      currentUsers = current.users;
      currentHasMore = current.hasMore;
    }

    try {
      final result = await followUserUseCase(
        FollowUserParams(
          followerId: event.followerId,
          followingId: event.followingId,
          isFollowing: event.isFollowing,
        ),
      );

      result.fold(
        (failure) {
          final message = ErrorMessageMapper.getErrorMessage(failure);

          // If we have a visible list, emit FollowOperationFailed (keeps list).
          if (currentUsers.isNotEmpty) {
            emit(
              FollowOperationFailed(
                event.followingId,
                event.isFollowing,
                message,
                users: currentUsers,
                hasMore: currentHasMore,
              ),
            );
          } else {
            // No list to show — fall back to full error.
            emit(FollowersError(message));
          }
        },
        (_) {
          // Success: update the in-memory list if we have it so UI remains stable.
          if (currentUsers.isNotEmpty) {
            final idx = currentUsers.indexWhere(
              (u) => u.id == event.followingId,
            );
            if (idx != -1) {
              final updated = List<UserListEntity>.from(currentUsers);
              updated[idx] = updated[idx].copyWith(
                isFollowing: event.isFollowing,
              );
              emit(
                UserFollowed(
                  event.followingId,
                  event.isFollowing,
                  users: updated,
                  hasMore: currentHasMore,
                ),
              );
            } else {
              // Target not present in current list (e.g., we're viewing followers and followed user isn't in this page).
              // Still emit confirmation carrying the current list so UI doesn't drop.
              emit(
                UserFollowed(
                  event.followingId,
                  event.isFollowing,
                  users: currentUsers,
                  hasMore: currentHasMore,
                ),
              );
            }
          } else {
            // No list: emit a simple confirmation (empty list preserved)
            emit(
              UserFollowed(
                event.followingId,
                event.isFollowing,
                users: currentUsers,
                hasMore: currentHasMore,
              ),
            );
          }
        },
      );
    } catch (e) {
      // Unexpected error: keep list if present, else show full error
      final message = ErrorMessageMapper.getErrorMessage(e);
      if (currentUsers.isNotEmpty) {
        emit(
          FollowOperationFailed(
            event.followingId,
            event.isFollowing,
            message,
            users: currentUsers,
            hasMore: currentHasMore,
          ),
        );
      } else {
        emit(FollowersError(message));
      }
    } finally {
      _processingFollowIds.remove(event.followingId);
    }
  }

  Future<void> _onGetFollowers(
    GetFollowersEvent event,
    Emitter<FollowersState> emit,
  ) async {
    final bool isInitialLoad = event.lastCreatedAt == null;

    // If paging, keep existing list
    List<UserListEntity> currentUsers = [];
    if (!isInitialLoad) {
      final s = state;
      if (s is FollowersLoaded) currentUsers = s.users;
      if (s is FollowersLoadingMore) currentUsers = s.users;
      if (s is FollowersLoadMoreError) currentUsers = s.users;
      if (s is UserFollowed) currentUsers = s.users;
      if (s is FollowOperationFailed) currentUsers = s.users;
    }

    if (isInitialLoad) {
      emit(const FollowersLoading());
    } else {
      emit(FollowersLoadingMore(users: currentUsers));
    }

    final result = await getFollowersUseCase(
      GetFollowersParams(
        userId: event.userId,
        currentUserId: event.currentUserId,
        pageSize: event.pageSize,
        lastCreatedAt: event.lastCreatedAt,
        lastId: event.lastId,
      ),
    );

    result.fold(
      (failure) {
        final message = ErrorMessageMapper.getErrorMessage(failure);
        if (isInitialLoad) {
          emit(FollowersError(message));
        } else {
          emit(FollowersLoadMoreError(message, users: currentUsers));
        }
      },
      (users) {
        if (isInitialLoad) {
          final bool hasMore = users.length == (event.pageSize);
          emit(FollowersLoaded(users, hasMore: hasMore));
        } else {
          final List<UserListEntity> updated = List.from(currentUsers)
            ..addAll(users);
          final bool hasMore = users.length == (event.pageSize);
          emit(FollowersLoaded(updated, hasMore: hasMore));
        }
      },
    );
  }

  Future<void> _onGetFollowing(
    GetFollowingEvent event,
    Emitter<FollowersState> emit,
  ) async {
    final bool isInitialLoad = event.lastCreatedAt == null;

    // If paging, keep existing list
    List<UserListEntity> currentUsers = [];
    if (!isInitialLoad) {
      final s = state;
      if (s is FollowersLoaded) currentUsers = s.users;
      if (s is FollowersLoadingMore) currentUsers = s.users;
      if (s is FollowersLoadMoreError) currentUsers = s.users;
      if (s is UserFollowed) currentUsers = s.users;
      if (s is FollowOperationFailed) currentUsers = s.users;
    }

    if (isInitialLoad) {
      emit(const FollowersLoading());
    } else {
      emit(FollowersLoadingMore(users: currentUsers));
    }

    final result = await getFollowingUseCase(
      GetFollowingParams(
        userId: event.userId,
        currentUserId: event.currentUserId,
        pageSize: event.pageSize,
        lastCreatedAt: event.lastCreatedAt,
        lastId: event.lastId,
      ),
    );

    result.fold(
      (failure) {
        final message = ErrorMessageMapper.getErrorMessage(failure);
        if (isInitialLoad) {
          emit(FollowersError(message));
        } else {
          emit(FollowersLoadMoreError(message, users: currentUsers));
        }
      },
      (users) {
        if (isInitialLoad) {
          final bool hasMore = users.length == (event.pageSize);
          emit(FollowersLoaded(users, hasMore: hasMore));
        } else {
          final List<UserListEntity> updated = List.from(currentUsers)
            ..addAll(users);
          final bool hasMore = users.length == (event.pageSize);
          emit(FollowersLoaded(updated, hasMore: hasMore));
        }
      },
    );
  }

  Future<void> _onGetFollowStatus(
    GetFollowStatusEvent event,
    Emitter<FollowersState> emit,
  ) async {
    emit(const FollowersLoading());
    final result = await getFollowStatusUseCase(
      GetFollowStatusParams(
        followerId: event.followerId,
        followingId: event.followingId,
      ),
    );
    result.fold(
      (failure) =>
          emit(FollowersError(ErrorMessageMapper.getErrorMessage(failure))),
      (isFollowing) => emit(FollowStatusLoaded(event.followingId, isFollowing)),
    );
  }
}
