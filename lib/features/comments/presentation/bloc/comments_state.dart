part of 'comments_bloc.dart';

abstract class CommentsState extends Equatable {
  const CommentsState();

  @override
  List<Object?> get props => [];
}

class CommentsInitial extends CommentsState {}

class CommentsLoading extends CommentsState {}

class CommentsLoaded extends CommentsState {
  final List<CommentEntity> comments;

  const CommentsLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentsError extends CommentsState {
  final String message;

  const CommentsError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentAdded extends CommentsState {
  final String postId;

  const CommentAdded(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CommentsStreamStarted extends CommentsState {
  final String postId;

  const CommentsStreamStarted(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CommentsStreamStopped extends CommentsState {}
