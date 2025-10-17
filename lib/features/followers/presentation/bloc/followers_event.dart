part of 'followers_bloc.dart';

abstract class FollowersEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FollowUserEvent extends FollowersEvent {
  final String followerId;
  final String followingId;
  final bool isFollowing;

  FollowUserEvent({
    required this.followerId,
    required this.followingId,
    required this.isFollowing,
  });

  @override
  List<Object?> get props => [followerId, followingId, isFollowing];
}

class GetFollowersEvent extends FollowersEvent {
  final String userId;
  final int page;
  final int limit;

  GetFollowersEvent({required this.userId, this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [userId, page, limit];
}

class GetFollowingEvent extends FollowersEvent {
  final String userId;
  final int page;
  final int limit;

  GetFollowingEvent({required this.userId, this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [userId, page, limit];
}
