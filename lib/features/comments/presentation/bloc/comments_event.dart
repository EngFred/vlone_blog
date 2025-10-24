part of 'comments_bloc.dart';

abstract class CommentsEvent extends Equatable {
  const CommentsEvent();

  @override
  List<Object?> get props => [];
}

class GetCommentsEvent extends CommentsEvent {
  final String postId;

  const GetCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class AddCommentEvent extends CommentsEvent {
  final String postId;
  final String userId;
  final String text;
  final String? parentCommentId;

  const AddCommentEvent({
    required this.postId,
    required this.userId,
    required this.text,
    this.parentCommentId,
  });

  @override
  List<Object?> get props => [postId, userId, text, parentCommentId];
}

class StartCommentsStreamEvent extends CommentsEvent {
  final String postId;

  const StartCommentsStreamEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class StopCommentsStreamEvent extends CommentsEvent {
  const StopCommentsStreamEvent();
}

// Legacy event for backwards compatibility
class SubscribeToCommentsEvent extends CommentsEvent {
  final String postId;

  const SubscribeToCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class NewCommentsEvent extends CommentsEvent {
  final List<CommentEntity> newComments;

  const NewCommentsEvent(this.newComments);

  @override
  List<Object?> get props => [newComments];
}

// Internal event for real-time updates
class _RealtimeCommentReceivedEvent extends CommentsEvent {
  final String postId;
  final List<CommentEntity> comments;

  const _RealtimeCommentReceivedEvent(this.postId, this.comments);

  @override
  List<Object?> get props => [postId, comments];
}
