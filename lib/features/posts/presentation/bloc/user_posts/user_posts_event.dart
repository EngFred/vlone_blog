part of 'user_posts_bloc.dart';

abstract class UserPostsEvent extends Equatable {
  const UserPostsEvent();
  @override
  List<Object?> get props => [];
}

class GetUserPostsEvent extends UserPostsEvent {
  final String profileUserId;
  final String currentUserId;
  const GetUserPostsEvent({
    required this.profileUserId,
    required this.currentUserId,
  });
  @override
  List<Object?> get props => [profileUserId, currentUserId];
}

class LoadMoreUserPostsEvent extends UserPostsEvent {
  const LoadMoreUserPostsEvent();
}

class RefreshUserPostsEvent extends UserPostsEvent {
  final String profileUserId;
  final String currentUserId;
  final Completer<void>? refreshCompleter;

  const RefreshUserPostsEvent({
    required this.profileUserId,
    required this.currentUserId,
    this.refreshCompleter,
  });
  @override
  List<Object?> get props => [profileUserId, currentUserId, refreshCompleter];
}

class RemovePostFromUserPosts extends UserPostsEvent {
  final String postId;
  const RemovePostFromUserPosts(this.postId);
  @override
  List<Object?> get props => [postId];
}

class StartUserPostsRealtime extends UserPostsEvent {
  final String profileUserId;
  const StartUserPostsRealtime({required this.profileUserId});
  @override
  List<Object?> get props => [profileUserId];
}

class StopUserPostsRealtime extends UserPostsEvent {
  const StopUserPostsRealtime();
}

// Internal realtime events (private to bloc)
class _RealtimeUserPostReceived extends UserPostsEvent {
  final PostEntity post;
  const _RealtimeUserPostReceived(this.post);
  @override
  List<Object?> get props => [post];
}

class _RealtimeUserPostUpdated extends UserPostsEvent {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  const _RealtimeUserPostUpdated({
    required this.postId,
    this.likesCount,
    this.commentsCount,
    this.favoritesCount,
  });
  @override
  List<Object?> get props => [
    postId,
    likesCount,
    commentsCount,
    favoritesCount,
  ];
}

class _RealtimeUserPostDeleted extends UserPostsEvent {
  final String postId;
  const _RealtimeUserPostDeleted(this.postId);
  @override
  List<Object?> get props => [postId];
}
