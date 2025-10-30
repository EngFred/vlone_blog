part of 'post_actions_bloc.dart';

abstract class PostActionsEvent extends Equatable {
  const PostActionsEvent();
  @override
  List<Object?> get props => [];
}

class CreatePostEvent extends PostActionsEvent {
  final String userId;
  final String? content;
  final File? mediaFile;
  final String? mediaType;
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

// ✅ ADDED: Optimistic update event
class OptimisticPostUpdate extends PostActionsEvent {
  final String postId;
  final int deltaLikes;
  final int deltaFavorites;
  final bool? isLiked;
  final bool? isFavorited;

  const OptimisticPostUpdate({
    required this.postId,
    required this.deltaLikes,
    required this.deltaFavorites,
    this.isLiked,
    this.isFavorited,
  });

  @override
  List<Object?> get props => [
    postId,
    deltaLikes,
    deltaFavorites,
    isLiked,
    isFavorited,
  ];
}
