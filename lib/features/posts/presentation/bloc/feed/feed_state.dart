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
  final List<PostEntity> posts;
  final Completer<void>? refreshCompleter;

  const FeedError(this.message, {this.posts = const [], this.refreshCompleter});

  @override
  List<Object?> get props => [message, posts, refreshCompleter];
}

class FeedLoaded extends FeedState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;
  final Completer<void>? refreshCompleter;

  const FeedLoaded(
    this.posts, {
    this.hasMore = true,
    this.isRealtimeActive = false,
    this.refreshCompleter,
  });

  @override
  List<Object?> get props => [
    posts,
    hasMore,
    isRealtimeActive,
    refreshCompleter,
  ];

  FeedLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
    Completer<void>? refreshCompleter,
  }) {
    return FeedLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
      refreshCompleter: refreshCompleter ?? this.refreshCompleter,
    );
  }
}

class FeedLoadingMore extends FeedState {
  final List<PostEntity> posts;
  const FeedLoadingMore({required this.posts});
  @override
  List<Object?> get props => [posts];
}

class FeedLoadMoreError extends FeedState {
  final String message;
  final List<PostEntity> posts;
  const FeedLoadMoreError(this.message, {required this.posts});
  @override
  List<Object?> get props => [message, posts];
}
