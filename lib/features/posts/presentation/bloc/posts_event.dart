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
  final String? viewerUserId; // For interactions
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
