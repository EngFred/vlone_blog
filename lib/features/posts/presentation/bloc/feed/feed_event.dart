part of 'feed_bloc.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class GetFeedEvent extends FeedEvent {
  final String userId;
  const GetFeedEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class LoadMoreFeedEvent extends FeedEvent {
  const LoadMoreFeedEvent();
}

class RefreshFeedEvent extends FeedEvent {
  final String userId;
  const RefreshFeedEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

// For optimistic updates (e.g., liking a post)
class UpdateFeedPostOptimistic extends FeedEvent {
  final String postId;
  final int deltaLikes;
  final int deltaFavorites;
  final int deltaComments;
  final bool? isLiked;
  final bool? isFavorited;

  const UpdateFeedPostOptimistic({
    required this.postId,
    this.deltaLikes = 0,
    this.deltaFavorites = 0,
    this.deltaComments = 0,
    this.isLiked,
    this.isFavorited,
  });

  @override
  List<Object?> get props => [
    postId,
    deltaLikes,
    deltaFavorites,
    deltaComments,
    isLiked,
    isFavorited,
  ];
}

// For reacting to PostActionsBloc (e.g., post created/deleted)
class AddPostToFeed extends FeedEvent {
  final PostEntity post;
  const AddPostToFeed(this.post);
  @override
  List<Object?> get props => [post];
}

class RemovePostFromFeed extends FeedEvent {
  final String postId;
  const RemovePostFromFeed(this.postId);
  @override
  List<Object?> get props => [postId];
}

// For managing its own realtime subscription
class StartFeedRealtime extends FeedEvent {
  const StartFeedRealtime();
}

class StopFeedRealtime extends FeedEvent {
  const StopFeedRealtime();
}

class _RealtimeFeedPostReceived extends FeedEvent {
  final PostEntity post;
  const _RealtimeFeedPostReceived(this.post);
  @override
  List<Object?> get props => [post];
}

class _RealtimeFeedPostUpdated extends FeedEvent {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;
  const _RealtimeFeedPostUpdated({
    required this.postId,
    this.likesCount,
    this.commentsCount,
    this.favoritesCount,
    this.sharesCount,
  });
}

class _RealtimeFeedPostDeleted extends FeedEvent {
  final String postId;
  const _RealtimeFeedPostDeleted(this.postId);
  @override
  List<Object?> get props => [postId];
}
