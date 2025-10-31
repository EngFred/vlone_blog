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

// ✅ MODIFIED: OptimisticPostUpdate now carries the full PostEntity
class OptimisticPostUpdate extends PostActionsEvent {
  // We pass the *current* post to be updated
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

  // Helper to maintain compatibility if needed, but props is what matters
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
