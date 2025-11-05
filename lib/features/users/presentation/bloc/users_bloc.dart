import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/features/users/domain/usecases/get_paginated_users_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';
part 'users_event.dart';
part 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final GetPaginatedUsersUseCase getPaginatedUsersUseCase;
  final RealtimeService _realtimeService = di.sl<RealtimeService>();

  DateTime? _lastCreatedAt;
  String? _lastId;

  static const int _pageSize = 20;
  bool _hasMore = true;
  String? _currentUserId;

  UsersBloc({required this.getPaginatedUsersUseCase}) : super(UsersInitial()) {
    on<GetPaginatedUsersEvent>(_onGetPaginatedUsers);
    on<LoadMoreUsersEvent>(_onLoadMoreUsers);
    on<RefreshUsersEvent>(_onRefreshUsers);
    on<UpdateUserFollowStatusEvent>(_onUpdateUserFollowStatus);
    on<_NewUserEvent>(_onNewUser);

    _realtimeService.onNewUser.listen((user) {
      add(_NewUserEvent(user));
    });
  }

  Future<void> _onGetPaginatedUsers(
    GetPaginatedUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    _currentUserId = event.currentUserId;
    // Removed the offset check, always load on initial event
    emit(UsersLoading());
    await _fetchUsers(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreUsers(
    LoadMoreUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_currentUserId == null || !_hasMore || state is UsersLoadingMore) {
      return;
    }
    final currentUsers = state is UsersLoaded
        ? (state as UsersLoaded).users
        : <UserListEntity>[];
    emit(UsersLoadingMore(currentUsers));
    await _fetchUsers(emit, isRefresh: false);
  }

  Future<void> _onRefreshUsers(
    RefreshUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    _currentUserId = event.currentUserId;
    // Reset cursor state for refresh
    _lastCreatedAt = null;
    _lastId = null;
    _hasMore = true;

    // Do not emit UsersLoading here, RefreshIndicator handles the visual cue
    await _fetchUsers(
      emit,
      isRefresh: true,
      refreshCompleter: event.refreshCompleter,
    );
  }

  void _onUpdateUserFollowStatus(
    UpdateUserFollowStatusEvent event,
    Emitter<UsersState> emit,
  ) {
    final currentState = state;
    // Only update if current state is UsersLoaded (and copy over the Completer if present)
    if (currentState is! UsersLoaded) return;

    final index = currentState.users.indexWhere(
      (user) => user.id == event.userId,
    );
    if (index == -1) return;

    final updatedUsers = List<UserListEntity>.from(currentState.users);
    updatedUsers[index] = updatedUsers[index].copyWith(
      isFollowing: event.isFollowing,
    );
    emit(
      UsersLoaded(
        updatedUsers,
        hasMore: currentState.hasMore,
        refreshCompleter:
            currentState.refreshCompleter, // Pass completer through
      ),
    );
  }

  Future<void> _fetchUsers(
    Emitter<UsersState> emit, {
    required bool isRefresh,
    // Added optional Completer
    Completer<void>? refreshCompleter,
  }) async {
    if (_currentUserId == null) {
      // Pass completer on error
      emit(
        UsersError(
          'User not authenticated',
          refreshCompleter: refreshCompleter,
        ),
      );
      refreshCompleter?.complete();
      return;
    }

    // Determine the cursor to pass (null on refresh, current state otherwise)
    final DateTime? cursorCreatedAt = isRefresh ? null : _lastCreatedAt;
    final String? cursorId = isRefresh ? null : _lastId;

    final result = await getPaginatedUsersUseCase(
      GetPaginatedUsersParams(
        currentUserId: _currentUserId!,
        pageSize: _pageSize,
        // Pass the cursor keys
        lastCreatedAt: cursorCreatedAt,
        lastId: cursorId,
      ),
    );

    result.fold(
      (failure) {
        final errorMessage = ErrorMessageMapper.getErrorMessage(failure);
        final currentUsers = state is UsersLoaded
            ? (state as UsersLoaded).users
            : (state is UsersLoadingMore
                  ? (state as UsersLoadingMore).currentUsers
                  : <UserListEntity>[]);

        if (isRefresh) {
          // On refresh error, emit UsersError with existing users list (if any) and the completer
          emit(
            UsersError(
              errorMessage,
              users: currentUsers,
              refreshCompleter: refreshCompleter,
            ),
          );
        } else {
          // On load more error, emit UsersLoadMoreError
          emit(UsersLoadMoreError(errorMessage, currentUsers: currentUsers));
        }
        // Complete the refresh indicator on error
        refreshCompleter?.complete();
      },
      (newUsers) {
        final List<UserListEntity> updatedUsers;

        if (isRefresh) {
          // On refresh, the new list *is* the updated list
          updatedUsers = newUsers;
        } else {
          // On load more, append new users to current list
          final currentUsers = state is UsersLoaded
              ? (state as UsersLoaded).users
              : (state is UsersLoadingMore
                    ? (state as UsersLoadingMore).currentUsers
                    : <UserListEntity>[]);

          updatedUsers = List<UserListEntity>.from(currentUsers)
            ..addAll(newUsers);
        }

        // <<-- UPDATE CURSOR STATE FOR NEXT PAGE -->>
        if (newUsers.isNotEmpty) {
          final lastUser = newUsers.last;
          _lastCreatedAt = lastUser.createdAt;
          _lastId = lastUser.id;
        }

        _hasMore = newUsers.length == _pageSize;
        // Emit UsersLoaded with the completer
        emit(
          UsersLoaded(
            updatedUsers,
            hasMore: _hasMore,
            refreshCompleter: refreshCompleter,
          ),
        );
        // Complete the refresh indicator on success
        refreshCompleter?.complete();
      },
    );
  }

  Future<void> _onNewUser(_NewUserEvent event, Emitter<UsersState> emit) async {
    final currentState = state;
    if (currentState is UsersLoaded &&
        _currentUserId != null &&
        event.user.id != _currentUserId) {
      final userExists = currentState.users.any((u) => u.id == event.user.id);
      if (!userExists) {
        final updatedUsers = [event.user, ...currentState.users];
        emit(
          UsersLoaded(
            updatedUsers,
            hasMore: currentState.hasMore,
            refreshCompleter:
                currentState.refreshCompleter, // Pass completer through
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _realtimeService.dispose();
    return super.close();
  }
}
