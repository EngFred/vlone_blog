part of 'posts_bloc.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

// ==================== CREATE POST ====================
class CreatePostEvent extends PostsEvent {
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

// ==================== GET FEED ====================
class GetFeedEvent extends PostsEvent {
  final String userId;

  const GetFeedEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

// ==================== GET REELS ====================
class GetReelsEvent extends PostsEvent {
  final String userId;

  const GetReelsEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

// ==================== GET USER POSTS ====================
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

// ==================== GET SINGLE POST ====================
class GetPostEvent extends PostsEvent {
  final String postId;
  final String currentUserId;

  const GetPostEvent({required this.postId, required this.currentUserId});

  @override
  List<Object?> get props => [postId, currentUserId];
}

// ==================== DELETE POST ====================
class DeletePostEvent extends PostsEvent {
  final String postId;

  const DeletePostEvent({required this.postId});

  @override
  List<Object?> get props => [postId];
}

// ==================== LIKE POST ====================
class LikePostEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isLiked;

  const LikePostEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}

// ==================== SHARE POST ====================
class SharePostEvent extends PostsEvent {
  final String postId;

  const SharePostEvent({required this.postId});

  @override
  List<Object?> get props => [postId];
}

// ==================== FAVORITE POST ====================
class FavoritePostEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  const FavoritePostEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

// ==================== REAL-TIME EVENTS ====================
// Start/Stop real-time listeners
class StartRealtimeListenersEvent extends PostsEvent {
  final String userId;

  const StartRealtimeListenersEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class StopRealtimeListenersEvent extends PostsEvent {
  const StopRealtimeListenersEvent();

  @override
  List<Object?> get props => [];
}

// Internal real-time events (not dispatched externally)
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

class _RealtimeLikeEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isLiked;

  const _RealtimeLikeEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}

class _RealtimeCommentEvent extends PostsEvent {
  final String postId;

  const _RealtimeCommentEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class _RealtimeFavoriteEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  const _RealtimeFavoriteEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

class _RealtimePostDeletedEvent extends PostsEvent {
  final String postId;

  const _RealtimePostDeletedEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}
