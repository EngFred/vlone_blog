part of 'user_posts_bloc.dart';

abstract class UserPostsState extends Equatable {
  /// The ID of the profile these posts belong to.
  /// This is crucial for the UI to know if the state is for the correct user.
  final String? profileUserId;

  const UserPostsState({required this.profileUserId});

  @override
  List<Object?> get props => [profileUserId];
}

class UserPostsInitial extends UserPostsState {
  const UserPostsInitial() : super(profileUserId: null);
}

class UserPostsLoading extends UserPostsState {
  const UserPostsLoading({required super.profileUserId});
}

class UserPostsError extends UserPostsState {
  final String message;
  final Completer<void>? refreshCompleter;

  const UserPostsError(
    this.message, {
    required super.profileUserId,
    this.refreshCompleter,
  });

  @override
  List<Object?> get props => [profileUserId, message, refreshCompleter];
}

class UserPostsLoaded extends UserPostsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;
  final Completer<void>? refreshCompleter;

  const UserPostsLoaded(
    this.posts, {
    required super.profileUserId,
    this.hasMore = true,
    this.isRealtimeActive = false,
    this.refreshCompleter,
  });

  @override
  List<Object?> get props => [
    profileUserId,
    posts,
    hasMore,
    isRealtimeActive,
    refreshCompleter,
  ];

  UserPostsLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
    String? profileUserId,
    Completer<void>? refreshCompleter,
  }) {
    return UserPostsLoaded(
      posts ?? this.posts,
      profileUserId: profileUserId ?? this.profileUserId,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
      refreshCompleter: refreshCompleter,
    );
  }
}

class UserPostsLoadingMore extends UserPostsState {
  final List<PostEntity> posts;

  const UserPostsLoadingMore({
    required this.posts,
    required super.profileUserId,
  });

  @override
  List<Object?> get props => [profileUserId, posts];
}

class UserPostsLoadMoreError extends UserPostsState {
  final String message;
  final List<PostEntity> posts;

  const UserPostsLoadMoreError(
    this.message, {
    required this.posts,
    required super.profileUserId,
  });

  @override
  List<Object?> get props => [profileUserId, message, posts];
}
