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

  // Pagination state
  int _currentOffset = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  String? _currentUserId;

  UsersBloc({required this.getPaginatedUsersUseCase}) : super(UsersInitial()) {
    on<GetPaginatedUsersEvent>(_onGetPaginatedUsers);
    on<LoadMoreUsersEvent>(_onLoadMoreUsers);
    on<RefreshUsersEvent>(_onRefreshUsers);
    on<UpdateUserFollowStatusEvent>(_onUpdateUserFollowStatus);
    on<_NewUserEvent>(_onNewUser); // Internal event for real-time new users

    // Listen to real-time new users from RealtimeService
    _realtimeService.onNewUser.listen((user) {
      add(_NewUserEvent(user));
    });
  }

  Future<void> _onGetPaginatedUsers(
    GetPaginatedUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    _currentUserId = event.currentUserId;
    if (_currentOffset != 0) return; // Initial load only
    emit(UsersLoading());
    await _fetchUsers(emit, isRefresh: true);
  }

  Future<void> _onLoadMoreUsers(
    LoadMoreUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_currentUserId == null || !_hasMore || state is UsersLoadingMore)
      return;
    emit(UsersLoadingMore());
    await _fetchUsers(emit, isRefresh: false);
  }

  Future<void> _onRefreshUsers(
    RefreshUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    _currentUserId = event.currentUserId;
    _currentOffset = 0;
    _hasMore = true;
    emit(UsersLoading());
    await _fetchUsers(emit, isRefresh: true);
  }

  void _onUpdateUserFollowStatus(
    UpdateUserFollowStatusEvent event,
    Emitter<UsersState> emit,
  ) {
    if (state is! UsersLoaded) return;
    final currentState = state as UsersLoaded;
    final index = currentState.users.indexWhere(
      (user) => user.id == event.userId,
    );
    if (index == -1) return; // User not in list

    final updatedUsers = List<UserListEntity>.from(currentState.users);
    updatedUsers[index] = updatedUsers[index].copyWith(
      isFollowing: event.isFollowing,
    );
    emit(UsersLoaded(updatedUsers, hasMore: currentState.hasMore));
  }

  Future<void> _fetchUsers(
    Emitter<UsersState> emit, {
    required bool isRefresh,
  }) async {
    if (_currentUserId == null) {
      emit(UsersError('User not authenticated'));
      return;
    }
    final result = await getPaginatedUsersUseCase(
      GetPaginatedUsersParams(
        currentUserId: _currentUserId!,
        pageSize: _pageSize,
        pageOffset: _currentOffset,
      ),
    );
    result.fold(
      (failure) {
        if (isRefresh) {
          emit(UsersError(ErrorMessageMapper.getErrorMessage(failure)));
        } else {
          emit(
            UsersLoadMoreError(
              ErrorMessageMapper.getErrorMessage(failure),
              currentUsers: state is UsersLoaded
                  ? (state as UsersLoaded).users
                  : [],
            ),
          );
        }
      },
      (newUsers) {
        final updatedUsers =
            isRefresh
                  ? newUsers
                  : (state is UsersLoaded
                        ? List<UserListEntity>.from(
                            (state as UsersLoaded).users,
                          )
                        : <UserListEntity>[])
              ..addAll(newUsers);
        _currentOffset += _pageSize;
        _hasMore = newUsers.length == _pageSize;
        emit(UsersLoaded(updatedUsers, hasMore: _hasMore));
      },
    );
  }

  Future<void> _onNewUser(_NewUserEvent event, Emitter<UsersState> emit) async {
    final currentState = state;
    if (currentState is UsersLoaded &&
        _currentUserId != null &&
        event.user.id != _currentUserId) {
      // Prepend new user (assuming recency order) and exclude self
      final updatedUsers = [event.user, ...currentState.users];
      emit(UsersLoaded(updatedUsers, hasMore: currentState.hasMore));
    }
  }

  @override
  Future<void> close() {
    _realtimeService
        .dispose(); // If needed; assuming it handles its own cleanup
    return super.close();
  }
}
