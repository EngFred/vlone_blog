part of 'followers_bloc.dart';

abstract class FollowersState extends Equatable {
  const FollowersState();

  @override
  List<Object?> get props => [];
}

class FollowersInitial extends FollowersState {
  const FollowersInitial();
}

class FollowersLoading extends FollowersState {
  const FollowersLoading();
}

class FollowersLoaded extends FollowersState {
  final List<UserListEntity> users;
  final bool hasMore;

  const FollowersLoaded(this.users, {this.hasMore = true});

  @override
  List<Object?> get props => [users, hasMore];

  FollowersLoaded copyWith({List<UserListEntity>? users, bool? hasMore}) {
    return FollowersLoaded(
      users ?? this.users,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FollowersLoadingMore extends FollowersState {
  final List<UserListEntity> users;
  const FollowersLoadingMore({required this.users});
  @override
  List<Object?> get props => [users];
}

class FollowersLoadMoreError extends FollowersState {
  final String message;
  final List<UserListEntity> users;
  const FollowersLoadMoreError(this.message, {required this.users});
  @override
  List<Object?> get props => [message, users];
}

class FollowersError extends FollowersState {
  final String message;
  const FollowersError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Emitted when a follow/unfollow completes. Carries the list so UI keeps rendering.
class UserFollowed extends FollowersState {
  final String followedUserId;
  final bool isFollowing;
  final List<UserListEntity> users;
  final bool hasMore;

  const UserFollowed(
    this.followedUserId,
    this.isFollowing, {
    this.users = const [],
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [followedUserId, isFollowing, users, hasMore];
}

/// Emitted when a follow operation failed but we still have a list to keep visible.
class FollowOperationFailed extends FollowersState {
  final String followedUserId;
  final bool attemptedIsFollowing;
  final String message;
  final List<UserListEntity> users;
  final bool hasMore;

  const FollowOperationFailed(
    this.followedUserId,
    this.attemptedIsFollowing,
    this.message, {
    this.users = const [],
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [
    followedUserId,
    attemptedIsFollowing,
    message,
    users,
    hasMore,
  ];
}

class FollowStatusLoaded extends FollowersState {
  final String followingId;
  final bool isFollowing;
  const FollowStatusLoaded(this.followingId, this.isFollowing);
  @override
  List<Object?> get props => [followingId, isFollowing];
}
