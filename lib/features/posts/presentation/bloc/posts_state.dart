part of 'posts_bloc.dart';

abstract class PostsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {}

class PostsLoading extends PostsState {}

class FeedLoaded extends PostsState {
  final List<PostEntity> posts;

  FeedLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
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

class PostsError extends PostsState {
  final String message;

  PostsError(this.message);

  @override
  List<Object?> get props => [message];
}
