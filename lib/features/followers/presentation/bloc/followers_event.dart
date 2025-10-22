part of 'followers_bloc.dart';

abstract class FollowersEvent extends Equatable {
  const FollowersEvent();

  @override
  List<Object?> get props => [];
}

class FollowUserEvent extends FollowersEvent {
  final String followerId;
  final String followingId;
  final bool isFollowing;

  const FollowUserEvent({
    required this.followerId,
    required this.followingId,
    required this.isFollowing,
  });

  @override
  List<Object?> get props => [followerId, followingId, isFollowing];
}

class GetFollowersEvent extends FollowersEvent {
  final String userId;
  final String? currentUserId;

  const GetFollowersEvent({required this.userId, this.currentUserId});

  @override
  List<Object?> get props => [userId, currentUserId];
}

class GetFollowingEvent extends FollowersEvent {
  final String userId;
  final String? currentUserId;

  const GetFollowingEvent({required this.userId, this.currentUserId});

  @override
  List<Object?> get props => [userId, currentUserId];
}

class GetFollowStatusEvent extends FollowersEvent {
  final String followerId;
  final String followingId;

  const GetFollowStatusEvent({
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object?> get props => [followerId, followingId];
}
