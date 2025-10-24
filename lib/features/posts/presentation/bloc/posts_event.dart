part of 'posts_bloc.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

class CreatePostEvent extends PostsEvent {
  final String userId;
  final String? content;
  final File? mediaFile;
  final String? mediaType;

  const CreatePostEvent({
    required this.userId,
    required this.content,
    this.mediaFile,
    this.mediaType,
  });

  @override
  List<Object?> get props => [userId, content, mediaFile, mediaType];
}

class GetFeedEvent extends PostsEvent {
  final String userId;

  const GetFeedEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class GetReelsEvent extends PostsEvent {
  final String userId;

  const GetReelsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class GetUserPostsEvent extends PostsEvent {
  final String profileUserId;
  final String currentUserId;

  const GetUserPostsEvent({
    required this.profileUserId,
    required this.currentUserId,
  });

  @override
  List<Object?> get props => [profileUserId, currentUserId];
}

class GetPostEvent extends PostsEvent {
  final String postId;
  final String currentUserId;

  const GetPostEvent({required this.postId, required this.currentUserId});

  @override
  List<Object?> get props => [postId, currentUserId];
}

class DeletePostEvent extends PostsEvent {
  final String postId;

  const DeletePostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class SharePostEvent extends PostsEvent {
  final String postId;

  const SharePostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

// ==================== REAL-TIME EVENTS ====================

class StartRealtimeListenersEvent extends PostsEvent {
  final String userId;

  const StartRealtimeListenersEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class StopRealtimeListenersEvent extends PostsEvent {
  const StopRealtimeListenersEvent();
}

// Internal events for real-time updates
class _RealtimePostReceivedEvent extends PostsEvent {
  final PostEntity post;

  const _RealtimePostReceivedEvent(this.post);

  @override
  List<Object?> get props => [post];
}

class _RealtimePostUpdatedEvent extends PostsEvent {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;

  const _RealtimePostUpdatedEvent({
    required this.postId,
    this.likesCount,
    this.commentsCount,
    this.favoritesCount,
    this.sharesCount,
  });

  @override
  List<Object?> get props => [
    postId,
    likesCount,
    commentsCount,
    favoritesCount,
    sharesCount,
  ];
}

class _RealtimePostDeletedEvent extends PostsEvent {
  final String postId;

  const _RealtimePostDeletedEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}
