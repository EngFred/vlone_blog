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
  // ADDED: Optional completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const RefreshReelsEvent(this.userId, {this.refreshCompleter});
  @override
  List<Object?> get props => [userId, refreshCompleter];
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
