part of 'posts_bloc.dart';

abstract class PostsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CreatePostEvent extends PostsEvent {
  final String userId;
  final String? content;
  final File? mediaFile;
  final String? mediaType;

  CreatePostEvent({
    required this.userId,
    this.content,
    this.mediaFile,
    this.mediaType,
  });

  @override
  List<Object?> get props => [userId, content, mediaFile, mediaType];
}

class GetFeedEvent extends PostsEvent {
  final String? userId;

  GetFeedEvent({this.userId});

  @override
  List<Object?> get props => [userId];
}

class GetReelsEvent extends PostsEvent {
  final String? userId;

  GetReelsEvent({this.userId});

  @override
  List<Object?> get props => [userId];
}

class GetUserPostsEvent extends PostsEvent {
  final String profileUserId;
  final String? viewerUserId;

  GetUserPostsEvent({required this.profileUserId, this.viewerUserId});

  @override
  List<Object?> get props => [profileUserId, viewerUserId];
}

class GetPostEvent extends PostsEvent {
  final String postId;
  final String? viewerUserId;

  GetPostEvent(this.postId, {this.viewerUserId});

  @override
  List<Object?> get props => [postId, viewerUserId];
}

class LikePostEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isLiked;

  LikePostEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}

class SharePostEvent extends PostsEvent {
  final String postId;

  SharePostEvent({required this.postId});

  @override
  List<Object?> get props => [postId];
}

// ==================== REAL-TIME EVENTS ====================

/// Start listening to real-time post updates
class StartRealtimeListenersEvent extends PostsEvent {
  final String? userId;

  StartRealtimeListenersEvent({this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Stop listening to real-time post updates
class StopRealtimeListenersEvent extends PostsEvent {}

/// Internal event when a new post is received via real-time
class _RealtimePostReceivedEvent extends PostsEvent {
  final PostEntity post;

  _RealtimePostReceivedEvent(this.post);

  @override
  List<Object?> get props => [post];
}

/// Internal event when post counts are updated via real-time
class _RealtimePostUpdatedEvent extends PostsEvent {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;

  _RealtimePostUpdatedEvent({
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

/// Internal event when a like event is received
class _RealtimeLikeEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isLiked;

  _RealtimeLikeEvent({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  @override
  List<Object?> get props => [postId, userId, isLiked];
}

/// Internal event when a comment event is received
class _RealtimeCommentEvent extends PostsEvent {
  final String postId;

  _RealtimeCommentEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Internal event when a favorite event is received
class _RealtimeFavoriteEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  _RealtimeFavoriteEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

/// Internal event when a post deletion event is received
class _RealtimePostDeletedEvent extends PostsEvent {
  final String postId;

  _RealtimePostDeletedEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class FavoritePostEvent extends PostsEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  FavoritePostEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

class DeletePostEvent extends PostsEvent {
  final String postId;

  DeletePostEvent({required this.postId});

  @override
  List<Object?> get props => [postId];
}
