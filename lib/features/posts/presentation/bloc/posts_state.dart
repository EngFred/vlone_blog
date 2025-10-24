// lib/features/posts/presentation/bloc/posts_state.dart
part of 'posts_bloc.dart';

abstract class PostsState extends Equatable {
  const PostsState();

  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {
  const PostsInitial();
}

class PostsLoading extends PostsState {
  const PostsLoading();
}

class PostsError extends PostsState {
  final String message;

  const PostsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PostCreated extends PostsState {
  final PostEntity post;

  const PostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

class FeedLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  const FeedLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];
}

class ReelsLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  const ReelsLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];
}

class UserPostsLoading extends PostsState {
  const UserPostsLoading();
}

class UserPostsLoaded extends PostsState {
  final List<PostEntity> posts;

  const UserPostsLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class UserPostsError extends PostsState {
  final String message;

  const UserPostsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PostLoaded extends PostsState {
  final PostEntity post;

  const PostLoaded(this.post);

  @override
  List<Object?> get props => [post];
}

class PostDeleting extends PostsState {
  final String postId;

  const PostDeleting(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostDeleted extends PostsState {
  final String postId;

  const PostDeleted(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostDeleteError extends PostsState {
  final String postId;
  final String message;

  const PostDeleteError(this.postId, this.message);

  @override
  List<Object?> get props => [postId, message];
}

class PostShared extends PostsState {
  final String postId;

  const PostShared(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostShareError extends PostsState {
  final String postId;
  final String message;

  const PostShareError(this.postId, this.message);

  @override
  List<Object?> get props => [postId, message];
}

// Real-time update notification state
class RealtimePostUpdate extends PostsState {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;

  const RealtimePostUpdate({
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
