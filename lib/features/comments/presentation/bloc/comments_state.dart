part of 'comments_bloc.dart';

abstract class CommentsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CommentsInitial extends CommentsState {}

class CommentsLoading extends CommentsState {}

class CommentsLoaded extends CommentsState {
  final List<CommentEntity> rootComments;

  CommentsLoaded(this.rootComments);

  @override
  List<Object?> get props => [rootComments];
}

class CommentAdded extends CommentsState {
  final CommentEntity comment;
  CommentAdded(this.comment);
  @override
  List<Object?> get props => [comment];
}

class CommentsError extends CommentsState {
  final String message;
  CommentsError(this.message);
  @override
  List<Object?> get props => [message];
}
