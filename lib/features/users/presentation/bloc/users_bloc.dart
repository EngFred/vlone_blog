import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/features/users/domain/usecases/get_all_users_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

part 'users_event.dart';
part 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final GetAllUsersUseCase getAllUsersUseCase;
  final RealtimeService _realtimeService = di.sl<RealtimeService>();

  UsersBloc({required this.getAllUsersUseCase}) : super(UsersInitial()) {
    on<GetAllUsersEvent>(_onGetAllUsers);
    on<_NewUserEvent>(
      _onNewUser,
    ); // NEW: Internal event for real-time new users

    // NEW: Listen to real-time new users from RealtimeService
    _realtimeService.onNewUser.listen((user) {
      add(_NewUserEvent(user));
    });
  }

  Future<void> _onGetAllUsers(
    GetAllUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(UsersLoading());
    final result = await getAllUsersUseCase(event.currentUserId);
    result.fold(
      (failure) =>
          emit(UsersError(ErrorMessageMapper.getErrorMessage(failure))),
      (users) => emit(UsersLoaded(users)),
    );
  }

  // NEW: Handle real-time new user addition
  void _onNewUser(_NewUserEvent event, Emitter<UsersState> emit) {
    final currentState = state;
    if (currentState is UsersLoaded) {
      // Add the new user to the list (you can sort if needed, e.g., by username)
      final updatedUsers = List<UserListEntity>.from(currentState.users)
        ..add(event.user);
      // Optional: Sort alphabetically by username
      updatedUsers.sort((a, b) => a.username.compareTo(b.username));
      emit(UsersLoaded(updatedUsers));
    }
  }
}
