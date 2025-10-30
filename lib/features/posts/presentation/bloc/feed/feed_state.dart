part of 'feed_bloc.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {
  const FeedInitial();
}

class FeedLoading extends FeedState {
  const FeedLoading();
}

class FeedError extends FeedState {
  final String message;
  const FeedError(this.message);
  @override
  List<Object?> get props => [message];
}

class FeedLoaded extends FeedState {
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

  FeedLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
  }) {
    return FeedLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
    );
  }
}

class FeedLoadingMore extends FeedState {
  // We include current posts so the UI can still show them
  final List<PostEntity> currentPosts;
  const FeedLoadingMore({required this.currentPosts});
  @override
  List<Object?> get props => [currentPosts];
}

class FeedLoadMoreError extends FeedState {
  final String message;
  final List<PostEntity> currentPosts;
  const FeedLoadMoreError(this.message, {required this.currentPosts});
  @override
  List<Object?> get props => [message, currentPosts];
}
