part of 'followers_bloc.dart';

abstract class FollowersState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FollowersInitial extends FollowersState {}

class FollowersLoading extends FollowersState {}

class FollowersLoaded extends FollowersState {
  final List<ProfileEntity> users;

  FollowersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class FollowingLoaded extends FollowersState {
  final List<ProfileEntity> users;

  FollowingLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserFollowed extends FollowersState {
  final String followedUserId;
  final bool isFollowing;

  UserFollowed(this.followedUserId, this.isFollowing);

  @override
  List<Object?> get props => [followedUserId, isFollowing];
}

class FollowersError extends FollowersState {
  final String message;

  FollowersError(this.message);

  @override
  List<Object?> get props => [message];
}
