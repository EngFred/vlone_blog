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
    _lastCreatedAt = null;
    _lastId = null;
    _hasMore = true;

    // Not emitting UsersLoading here, RefreshIndicator handles the visual cue
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
        refreshCompleter: currentState.refreshCompleter,
      ),
    );
  }

  Future<void> _fetchUsers(
    Emitter<UsersState> emit, {
    required bool isRefresh,
    Completer<void>? refreshCompleter,
  }) async {
    if (_currentUserId == null) {
      emit(
        UsersError(
          'User not authenticated',
          refreshCompleter: refreshCompleter,
        ),
      );
      refreshCompleter?.complete();
      return;
    }

    final DateTime? cursorCreatedAt = isRefresh ? null : _lastCreatedAt;
    final String? cursorId = isRefresh ? null : _lastId;

    final result = await getPaginatedUsersUseCase(
      GetPaginatedUsersParams(
        currentUserId: _currentUserId!,
        pageSize: _pageSize,
        lastCreatedAt: cursorCreatedAt,
        lastId: cursorId,
      ),
    );

    result.fold(
      (failure) {
        final errorMessage = ErrorMessageMapper.getErrorMessage(failure);
        final currentUsers = _getCurrentUsersFromState();

        if (isRefresh) {
          emit(
            UsersError(
              errorMessage,
              users: currentUsers, // Preserve existing users on refresh error
              refreshCompleter: refreshCompleter,
            ),
          );
        } else {
          emit(UsersLoadMoreError(errorMessage, currentUsers: currentUsers));
        }
        refreshCompleter?.complete();
      },
      (newUsers) {
        final List<UserListEntity> updatedUsers;

        if (isRefresh) {
          updatedUsers = newUsers;
        } else {
          final currentUsers = _getCurrentUsersFromState();
          updatedUsers = List<UserListEntity>.from(currentUsers)
            ..addAll(newUsers);
        }
        if (newUsers.isNotEmpty) {
          final lastUser = newUsers.last;
          _lastCreatedAt = lastUser.createdAt;
          _lastId = lastUser.id;
        }

        _hasMore = newUsers.length == _pageSize;
        emit(
          UsersLoaded(
            updatedUsers,
            hasMore: _hasMore,
            refreshCompleter: refreshCompleter,
          ),
        );
        refreshCompleter?.complete();
      },
    );
  }

  List<UserListEntity> _getCurrentUsersFromState() {
    if (state is UsersLoaded) {
      return (state as UsersLoaded).users;
    } else if (state is UsersLoadingMore) {
      return (state as UsersLoadingMore).currentUsers;
    } else if (state is UsersError) {
      return (state as UsersError).users;
    }
    return <UserListEntity>[];
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
            refreshCompleter: currentState.refreshCompleter,
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
