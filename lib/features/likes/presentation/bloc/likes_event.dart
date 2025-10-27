part of 'likes_bloc.dart';

abstract class LikesEvent extends Equatable {
  const LikesEvent();

  @override
  List<Object?> get props => [];
}

class LikePostEvent extends LikesEvent {
  final String postId;
  final String userId;
  final bool isLiked; // the target state the user requested
  final bool previousState; // explicit UI state before the tap

  const LikePostEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
    required this.previousState,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked, previousState];
}

class StartLikesStreamEvent extends LikesEvent {
  final String userId;
  const StartLikesStreamEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class StopLikesStreamEvent extends LikesEvent {}

class _RealtimeLikeReceivedEvent extends LikesEvent {
  final String postId;
  final String userId;
  final bool isLiked;

  const _RealtimeLikeReceivedEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}
