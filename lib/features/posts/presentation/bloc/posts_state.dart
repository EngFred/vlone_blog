part of 'posts_bloc.dart';

abstract class PostsState extends Equatable {
  const PostsState();

  @override
  List<Object?> get props => [];
}

// ==================== INITIAL/LOADING/ERROR ====================
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

// ==================== FEED ====================
class FeedLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  const FeedLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];

  FeedLoaded copyWith({List<PostEntity>? posts, bool? isRealtimeActive}) {
    return FeedLoaded(
      posts ?? this.posts,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
    );
  }
}

// ==================== REELS ====================
class ReelsLoaded extends PostsState {
  final List<PostEntity> posts;
  final bool isRealtimeActive;

  const ReelsLoaded(this.posts, {this.isRealtimeActive = false});

  @override
  List<Object?> get props => [posts, isRealtimeActive];

  ReelsLoaded copyWith({List<PostEntity>? posts, bool? isRealtimeActive}) {
    return ReelsLoaded(
      posts ?? this.posts,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
    );
  }
}

// ==================== USER POSTS ====================
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

// ==================== SINGLE POST ====================
class PostLoaded extends PostsState {
  final PostEntity post;

  const PostLoaded(this.post);

  @override
  List<Object?> get props => [post];
}

// ==================== CREATE POST ====================
class PostCreated extends PostsState {
  final PostEntity post;

  const PostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

// ==================== DELETE POST ====================
class PostDeleting extends PostsState {
  final String postId;

  const PostDeleting(this.postId);

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

class PostDeleted extends PostsState {
  final String postId;

  const PostDeleted(this.postId);

  @override
  List<Object?> get props => [postId];
}

// ==================== INTERACTIONS ====================
class PostLiked extends PostsState {
  final String postId;
  final bool isLiked;

  const PostLiked(this.postId, this.isLiked);

  @override
  List<Object?> get props => [postId, isLiked];
}

class PostShared extends PostsState {
  final String postId;

  const PostShared(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostFavorited extends PostsState {
  final String postId;
  final bool isFavorited;

  const PostFavorited(this.postId, this.isFavorited);

  @override
  List<Object?> get props => [postId, isFavorited];
}

// ==================== REAL-TIME UPDATES ====================
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
