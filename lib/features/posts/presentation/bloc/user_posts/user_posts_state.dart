part of 'user_posts_bloc.dart';

abstract class UserPostsState extends Equatable {
  // Store profileUserId in the base state for consistency
  final String? profileUserId;
  const UserPostsState({this.profileUserId}); // <--- base constructor is OK

  @override
  List<Object?> get props => [profileUserId];
}

class UserPostsInitial extends UserPostsState {
  const UserPostsInitial() : super(profileUserId: null);
}

class UserPostsLoading extends UserPostsState {
  // FIX 1: Make parameter nullable and remove 'required'
  // (or keep required and ensure it's never null)
  const UserPostsLoading({super.profileUserId});
}

class UserPostsError extends UserPostsState {
  final String message;
  // FIX 2: Make parameter nullable and remove 'required'
  const UserPostsError(this.message, {String? super.profileUserId});

  @override
  List<Object?> get props => [message, profileUserId];
}

class UserPostsLoaded extends UserPostsState {
  final List<PostEntity> posts;
  final bool hasMore;

  const UserPostsLoaded(
    this.posts, {
    this.hasMore = true,
    // FIX 3: Make parameter nullable and remove 'required'
    String? super.profileUserId,
  });

  @override
  List<Object?> get props => [posts, hasMore, profileUserId];

  UserPostsLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    String? profileUserId,
  }) {
    return UserPostsLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      profileUserId: profileUserId ?? this.profileUserId,
    );
  }
}

class UserPostsLoadingMore extends UserPostsState {
  final List<PostEntity> currentPosts;
  const UserPostsLoadingMore({
    required this.currentPosts,
    String? super.profileUserId,
  }); // FIX 4

  @override
  List<Object?> get props => [currentPosts, profileUserId];
}

class UserPostsLoadMoreError extends UserPostsState {
  final String message;
  final List<PostEntity> currentPosts;
  const UserPostsLoadMoreError(
    this.message, {
    required this.currentPosts,
    String? super.profileUserId, // FIX 5
  });

  @override
  List<Object?> get props => [message, currentPosts, profileUserId];
}
