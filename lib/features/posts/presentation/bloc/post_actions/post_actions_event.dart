// post_actions_event.dart
part of 'post_actions_bloc.dart';

abstract class PostActionsEvent extends Equatable {
  const PostActionsEvent();
  @override
  List<Object?> get props => [];
}

// FIX: Issue 3 - New event for resetting form
class ResetForm extends PostActionsEvent {
  const ResetForm();
}

/// Existing events kept
class CreatePostEvent extends PostActionsEvent {
  final String userId;
  final String? content;
  final File? mediaFile;

  final MediaType? mediaType;

  const CreatePostEvent({
    required this.userId,
    this.content,
    this.mediaFile,
    this.mediaType,
  });

  @override
  List<Object?> get props => [userId, content, mediaFile, mediaType];
}

class GetPostEvent extends PostActionsEvent {
  final String postId;
  final String currentUserId;

  const GetPostEvent({required this.postId, required this.currentUserId});

  @override
  List<Object?> get props => [postId, currentUserId];
}

class DeletePostEvent extends PostActionsEvent {
  final String postId;

  const DeletePostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class SharePostEvent extends PostActionsEvent {
  final String postId;
  const SharePostEvent(this.postId);
  @override
  List<Object?> get props => [postId];
}

class OptimisticPostUpdate extends PostActionsEvent {
  final PostEntity post;
  final int deltaLikes;
  final int deltaFavorites;
  final bool? isLiked;
  final bool? isFavorited;

  const OptimisticPostUpdate({
    required this.post,
    this.deltaLikes = 0,
    this.deltaFavorites = 0,
    this.isLiked,
    this.isFavorited,
  });

  String get postId => post.id;

  @override
  List<Object?> get props => [
    post,
    deltaLikes,
    deltaFavorites,
    isLiked,
    isFavorited,
  ];
}

/// NEW: Form/UI events
class ContentChanged extends PostActionsEvent {
  final String content;
  const ContentChanged(this.content);
  @override
  List<Object?> get props => [content];
}

class MediaSelected extends PostActionsEvent {
  final File? file;
  final MediaType? type;
  const MediaSelected(this.file, this.type);
  @override
  List<Object?> get props => [file?.path, type];
}

/// Processing update can be triggered by MediaProgressNotifier or by widgets
class ProcessingChanged extends PostActionsEvent {
  final bool processing;
  final String? message;
  final double? percent;

  const ProcessingChanged({
    required this.processing,
    this.message,
    this.percent,
  }) : assert(percent == null || (percent >= 0.0 && percent <= 100.0));
  // helper constructor for simple toggles
  const ProcessingChanged.simple(bool processing)
    : this(processing: processing);

  @override
  List<Object?> get props => [processing, message, percent];
}
