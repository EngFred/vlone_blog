part of 'users_bloc.dart';

abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

class UsersInitial extends UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserListEntity> users;
  final bool hasMore;
  // Added Completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const UsersLoaded(this.users, {required this.hasMore, this.refreshCompleter});

  @override
  List<Object?> get props => [users, hasMore, refreshCompleter];
}

class UsersError extends UsersState {
  final String message;
  // Added optional list of users to display existing data on non-initial error
  final List<UserListEntity> users;
  // Added Completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const UsersError(
    this.message, {
    this.users = const [],
    this.refreshCompleter,
  });

  @override
  List<Object?> get props => [message, users, refreshCompleter];
}

// State used during the Load More process (shows partial list + loading indicator)
class UsersLoadingMore extends UsersState {
  final List<UserListEntity> currentUsers;

  const UsersLoadingMore(this.currentUsers);

  @override
  List<Object?> get props => [currentUsers];
}

// State used when Load More fails (shows partial list + error message)
class UsersLoadMoreError extends UsersState {
  final String message;
  final List<UserListEntity> currentUsers;

  const UsersLoadMoreError(this.message, {required this.currentUsers});

  @override
  List<Object?> get props => [message, currentUsers];
}
