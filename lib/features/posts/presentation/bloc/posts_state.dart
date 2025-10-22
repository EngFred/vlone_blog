part of 'posts_bloc.dart';

abstract class PostsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {}

class PostsLoading extends PostsState {}

class UserPostsLoading extends PostsState {}

class FeedLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  FeedLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];
}

class ReelsLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  ReelsLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];
}

class UserPostsLoaded extends PostsState {
  final List<PostEntity> posts;

  UserPostsLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class PostCreated extends PostsState {
  final PostEntity post;

  PostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

class PostLoaded extends PostsState {
  final PostEntity post;

  PostLoaded(this.post);

  @override
  List<Object?> get props => [post];
}

class PostLiked extends PostsState {
  final String postId;
  final bool isLiked;

  PostLiked(this.postId, this.isLiked);

  @override
  List<Object?> get props => [postId, isLiked];
}

class PostShared extends PostsState {
  final String postId;

  PostShared(this.postId);

  @override
  List<Object?> get props => [postId];
}

class UserPostsError extends PostsState {
  final String message;

  UserPostsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PostsError extends PostsState {
  final String message;

  PostsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State emitted when real-time update is received
class RealtimePostUpdate extends PostsState {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;

  RealtimePostUpdate({
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

class PostFavorited extends PostsState {
  final String postId;
  final bool isFavorited;

  PostFavorited(this.postId, this.isFavorited);

  @override
  List<Object?> get props => [postId, isFavorited];
}
