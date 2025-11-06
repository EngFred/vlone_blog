part of 'likes_bloc.dart';

abstract class LikesState extends Equatable {
  const LikesState();

  @override
  List<Object?> get props => [];
}

class LikesInitial extends LikesState {}

class LikesStreamStarted extends LikesState {}

class LikesStreamStopped extends LikesState {}

// Emitted for optimistic updates and also used for server-corrected updates.
// delta: +1 for like, -1 for unlike, 0 if server says state already matched (idempotent)
class LikeUpdated extends LikesState {
  final String postId;
  final String userId;
  final bool isLiked;
  final int delta;

  const LikeUpdated({
    required this.postId,
    required this.userId,
    required this.isLiked,
    required this.delta,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked, delta];
}

class LikeSuccess extends LikesState {
  final String postId;
  final String userId;
  final bool isLiked;

  const LikeSuccess({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}

class LikeError extends LikesState {
  final String postId;
  final String message;
  final bool shouldRevert;
  final bool previousState;
  final int delta;

  const LikeError({
    required this.postId,
    required this.message,
    required this.shouldRevert,
    required this.previousState,
    required this.delta,
  });

  @override
  List<Object?> get props => [
    postId,
    message,
    shouldRevert,
    previousState,
    delta,
  ];
}
