part of 'users_bloc.dart';

abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

class UsersInitial extends UsersState {}

class UsersLoading extends UsersState {}

class UsersLoadingMore extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserListEntity> users;
  final bool hasMore;

  const UsersLoaded(this.users, {this.hasMore = true});

  @override
  List<Object?> get props => [users, hasMore];
}

class UsersError extends UsersState {
  final String message;

  const UsersError(this.message);

  @override
  List<Object?> get props => [message];
}

class UsersLoadMoreError extends UsersState {
  final String message;
  final List<UserListEntity> currentUsers;

  const UsersLoadMoreError(this.message, {required this.currentUsers});

  @override
  List<Object?> get props => [message, currentUsers];
}
