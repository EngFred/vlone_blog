part of 'user_posts_bloc.dart';

abstract class UserPostsState extends Equatable {
  final String? profileUserId;
  const UserPostsState({this.profileUserId});

  @override
  List<Object?> get props => [profileUserId];
}

class UserPostsInitial extends UserPostsState {
  const UserPostsInitial() : super(profileUserId: null);
}

class UserPostsLoading extends UserPostsState {
  const UserPostsLoading({super.profileUserId});
}

class UserPostsError extends UserPostsState {
  final String message;
  const UserPostsError(this.message, {super.profileUserId});

  @override
  List<Object?> get props => [message, profileUserId];
}

class UserPostsLoaded extends UserPostsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;

  const UserPostsLoaded(
    this.posts, {
    this.hasMore = true,
    this.isRealtimeActive = false,
    super.profileUserId,
  });

  @override
  List<Object?> get props => [posts, hasMore, isRealtimeActive, profileUserId];

  UserPostsLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
    String? profileUserId,
  }) {
    return UserPostsLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
      profileUserId: profileUserId ?? this.profileUserId,
    );
  }
}

class UserPostsLoadingMore extends UserPostsState {
  final List<PostEntity> currentPosts;
  const UserPostsLoadingMore({required this.currentPosts, super.profileUserId});

  @override
  List<Object?> get props => [currentPosts, profileUserId];
}

class UserPostsLoadMoreError extends UserPostsState {
  final String message;
  final List<PostEntity> currentPosts;
  const UserPostsLoadMoreError(
    this.message, {
    required this.currentPosts,
    super.profileUserId,
  });

  @override
  List<Object?> get props => [message, currentPosts, profileUserId];
}
