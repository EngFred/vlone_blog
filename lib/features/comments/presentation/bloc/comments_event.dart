part of 'comments_bloc.dart';

abstract class CommentsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetCommentsEvent extends CommentsEvent {
  final String postId;

  GetCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class AddCommentEvent extends CommentsEvent {
  final String postId;
  final String userId;
  final String text;
  final String? parentCommentId;

  AddCommentEvent({
    required this.postId,
    required this.userId,
    required this.text,
    this.parentCommentId,
  });

  @override
  List<Object?> get props => [postId, userId, text, parentCommentId];
}

class SubscribeToCommentsEvent extends CommentsEvent {
  final String postId;

  SubscribeToCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class NewCommentsEvent extends CommentsEvent {
  final List<CommentEntity> newComments;

  NewCommentsEvent(this.newComments);

  @override
  List<Object?> get props => [newComments];
}
