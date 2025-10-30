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
  const RefreshUserPostsEvent({
    required this.profileUserId,
    required this.currentUserId,
  });
  @override
  List<Object?> get props => [profileUserId, currentUserId];
}

class RemovePostFromUserPosts extends UserPostsEvent {
  final String postId;
  const RemovePostFromUserPosts(this.postId);
  @override
  List<Object?> get props => [postId];
}
