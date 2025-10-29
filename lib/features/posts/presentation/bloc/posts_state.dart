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
  final bool hasMore;
  final bool isRealtimeActive;

  const FeedLoaded(
    this.posts, {
    this.hasMore = true,
    this.isRealtimeActive = false,
  });

  @override
  List<Object?> get props => [posts, hasMore, isRealtimeActive];
}

class FeedLoadingMore extends PostsState {
  const FeedLoadingMore();
}

class FeedLoadMoreError extends PostsState {
  final String message;
  final List<PostEntity> currentPosts;

  const FeedLoadMoreError(this.message, {required this.currentPosts});

  @override
  List<Object?> get props => [message, currentPosts];
}

class ReelsLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;

  const ReelsLoaded(
    this.posts, {
    this.hasMore = true,
    this.isRealtimeActive = false,
  });

  @override
  List<Object?> get props => [posts, hasMore, isRealtimeActive];
}

class ReelsLoadingMore extends PostsState {
  const ReelsLoadingMore();
}

class ReelsLoadMoreError extends PostsState {
  final String message;
  final List<PostEntity> currentPosts;

  const ReelsLoadMoreError(this.message, {required this.currentPosts});

  @override
  List<Object?> get props => [message, currentPosts];
}

// NEW: Added profileUserId to all user-posts states for per-profile isolation
class UserPostsLoading extends PostsState {
  final String? profileUserId; // Tracks which profile this loading is for

  const UserPostsLoading({this.profileUserId});

  @override
  List<Object?> get props => [profileUserId];
}

class UserPostsLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final String? profileUserId; // Tracks which profile these posts belong to

  const UserPostsLoaded(this.posts, {this.hasMore = true, this.profileUserId});

  @override
  List<Object?> get props => [posts, hasMore, profileUserId];
}

class UserPostsLoadingMore extends PostsState {
  final String? profileUserId; // For consistency during load more

  const UserPostsLoadingMore({this.profileUserId});

  @override
  List<Object?> get props => [profileUserId];
}

class UserPostsLoadMoreError extends PostsState {
  final String message;
  final List<PostEntity> currentPosts;
  final String? profileUserId; // Preserve for error context

  const UserPostsLoadMoreError(
    this.message, {
    required this.currentPosts,
    this.profileUserId,
  });

  @override
  List<Object?> get props => [message, currentPosts, profileUserId];
}

class UserPostsError extends PostsState {
  final String message;
  final String? profileUserId; // Tracks which profile errored

  const UserPostsError(this.message, {this.profileUserId});

  @override
  List<Object?> get props => [message, profileUserId];
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
