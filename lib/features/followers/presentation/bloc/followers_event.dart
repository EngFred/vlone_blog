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
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetFollowersEvent({
    required this.userId,
    this.currentUserId,
    this.pageSize = FollowersBloc.defaultPageSize,
    this.lastCreatedAt,
    this.lastId,
  });

  @override
  List<Object?> get props => [
    userId,
    currentUserId,
    pageSize,
    lastCreatedAt,
    lastId,
  ];
}

class GetFollowingEvent extends FollowersEvent {
  final String userId;
  final String? currentUserId;
  final int pageSize;
  final DateTime? lastCreatedAt;
  final String? lastId;

  const GetFollowingEvent({
    required this.userId,
    this.currentUserId,
    this.pageSize = FollowersBloc.defaultPageSize,
    this.lastCreatedAt,
    this.lastId,
  });

  @override
  List<Object?> get props => [
    userId,
    currentUserId,
    pageSize,
    lastCreatedAt,
    lastId,
  ];
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
