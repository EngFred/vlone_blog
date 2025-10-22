part of 'followers_bloc.dart';

abstract class FollowersState extends Equatable {
  const FollowersState();

  @override
  List<Object> get props => [];
}

class FollowersInitial extends FollowersState {}

class FollowersLoading extends FollowersState {}

class FollowersLoaded extends FollowersState {
  final List<UserListEntity> users;

  const FollowersLoaded(this.users);

  @override
  List<Object> get props => [users];
}

class FollowingLoaded extends FollowersState {
  final List<UserListEntity> users;

  const FollowingLoaded(this.users);

  @override
  List<Object> get props => [users];
}

class UserFollowed extends FollowersState {
  final String followedUserId;
  final bool isFollowing;

  const UserFollowed(this.followedUserId, this.isFollowing);

  @override
  List<Object> get props => [followedUserId, isFollowing];
}

class FollowersError extends FollowersState {
  final String message;

  const FollowersError(this.message);

  @override
  List<Object> get props => [message];
}

class FollowStatusLoaded extends FollowersState {
  final String followingId;
  final bool isFollowing;

  const FollowStatusLoaded(this.followingId, this.isFollowing);

  @override
  List<Object> get props => [followingId, isFollowing];
}
