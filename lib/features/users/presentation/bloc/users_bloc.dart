import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/users/domain/usecases/get_all_users_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

part 'users_event.dart';
part 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final GetAllUsersUseCase getAllUsersUseCase;

  UsersBloc({required this.getAllUsersUseCase}) : super(UsersInitial()) {
    on<GetAllUsersEvent>(_onGetAllUsers);
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
}
