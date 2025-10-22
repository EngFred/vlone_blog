part of 'users_bloc.dart';

abstract class UsersEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetAllUsersEvent extends UsersEvent {
  final String currentUserId;

  GetAllUsersEvent(this.currentUserId);

  @override
  List<Object?> get props => [currentUserId];
}
