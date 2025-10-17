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
  final int page;
  final int limit;

  GetFeedEvent({this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [page, limit];
}

class GetUserPostsEvent extends PostsEvent {
  final String userId;
  final int page;
  final int limit;

  GetUserPostsEvent({required this.userId, this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [userId, page, limit];
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

class SubscribeToFeedEvent extends PostsEvent {}

class NewPostsEvent extends PostsEvent {
  final List<PostEntity> newPosts;

  NewPostsEvent(this.newPosts);

  @override
  List<Object?> get props => [newPosts];
}
