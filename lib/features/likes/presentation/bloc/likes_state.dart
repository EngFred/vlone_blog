part of 'likes_bloc.dart';

abstract class LikesState extends Equatable {
  const LikesState();

  @override
  List<Object?> get props => [];
}

class LikesInitial extends LikesState {}

class LikeUpdated extends LikesState {
  final String postId;
  final String userId;
  final bool isLiked;

  const LikeUpdated({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
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

  const LikeError({
    required this.postId,
    required this.message,
    required this.shouldRevert,
    required this.previousState,
  });

  @override
  List<Object?> get props => [postId, message, shouldRevert, previousState];
}

class LikesStreamStarted extends LikesState {}

class LikesStreamStopped extends LikesState {}
