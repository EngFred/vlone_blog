part of 'users_bloc.dart';

abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class GetPaginatedUsersEvent extends UsersEvent {
  final String currentUserId;

  const GetPaginatedUsersEvent(this.currentUserId);

  @override
  List<Object?> get props => [currentUserId];
}

class LoadMoreUsersEvent extends UsersEvent {
  const LoadMoreUsersEvent();

  @override
  List<Object?> get props => [];
}

class RefreshUsersEvent extends UsersEvent {
  final String currentUserId;
  final Completer<void>? refreshCompleter;

  const RefreshUsersEvent(this.currentUserId, this.refreshCompleter);

  @override
  List<Object?> get props => [currentUserId];
}

class UpdateUserFollowStatusEvent extends UsersEvent {
  final String userId;
  final bool isFollowing;

  const UpdateUserFollowStatusEvent(this.userId, this.isFollowing);

  @override
  List<Object?> get props => [userId, isFollowing];
}

class _NewUserEvent extends UsersEvent {
  final UserListEntity user;
  const _NewUserEvent(this.user);

  @override
  List<Object?> get props => [user];
}
