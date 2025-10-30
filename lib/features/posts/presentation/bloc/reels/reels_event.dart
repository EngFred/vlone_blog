part of 'reels_bloc.dart';

abstract class ReelsEvent extends Equatable {
  const ReelsEvent();
  @override
  List<Object?> get props => [];
}

class GetReelsEvent extends ReelsEvent {
  final String userId;
  const GetReelsEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class LoadMoreReelsEvent extends ReelsEvent {
  const LoadMoreReelsEvent();
}

class RefreshReelsEvent extends ReelsEvent {
  final String userId;
  const RefreshReelsEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class UpdateReelsPostOptimistic extends ReelsEvent {
  final String postId;
  final int deltaLikes;
  final int deltaFavorites;
  final int deltaComments;
  final bool? isLiked;
  final bool? isFavorited;

  const UpdateReelsPostOptimistic({
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

class RemovePostFromReels extends ReelsEvent {
  final String postId;
  const RemovePostFromReels(this.postId);
  @override
  List<Object?> get props => [postId];
}

class StartReelsRealtime extends ReelsEvent {
  const StartReelsRealtime();
}

class StopReelsRealtime extends ReelsEvent {
  const StopReelsRealtime();
}

class _RealtimeReelsPostReceived extends ReelsEvent {
  final PostEntity post;
  const _RealtimeReelsPostReceived(this.post);
  @override
  List<Object?> get props => [post];
}

class _RealtimeReelsPostUpdated extends ReelsEvent {
  final String postId;
  final int? likesCount;
  final int? commentsCount;
  final int? favoritesCount;
  final int? sharesCount;
  const _RealtimeReelsPostUpdated({
    required this.postId,
    this.likesCount,
    this.commentsCount,
    this.favoritesCount,
    this.sharesCount,
  });
}

class _RealtimeReelsPostDeleted extends ReelsEvent {
  final String postId;
  const _RealtimeReelsPostDeleted(this.postId);
  @override
  List<Object?> get props => [postId];
}
