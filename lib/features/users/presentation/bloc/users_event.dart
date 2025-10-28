part of 'users_bloc.dart';

abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class GetAllUsersEvent extends UsersEvent {
  final String currentUserId;

  const GetAllUsersEvent(this.currentUserId);

  @override
  List<Object?> get props => [currentUserId];
}

class _NewUserEvent extends UsersEvent {
  final UserListEntity user;
  const _NewUserEvent(this.user);

  @override
  List<Object?> get props => [user];
}
