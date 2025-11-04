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
  // RENAMED from currentPosts to posts for consistency
  final List<PostEntity> posts;
  const FeedLoadingMore({required this.posts});
  @override
  List<Object?> get props => [posts];
}

class FeedLoadMoreError extends FeedState {
  final String message;
  // RENAMED from currentPosts to posts for consistency
  final List<PostEntity> posts;
  const FeedLoadMoreError(this.message, {required this.posts});
  @override
  List<Object?> get props => [message, posts];
}
