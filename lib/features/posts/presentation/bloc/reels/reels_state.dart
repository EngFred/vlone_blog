part of 'reels_bloc.dart';

abstract class ReelsState extends Equatable {
  const ReelsState();
  @override
  List<Object?> get props => [];
}

class ReelsInitial extends ReelsState {
  const ReelsInitial();
}

class ReelsLoading extends ReelsState {
  const ReelsLoading();
}

class ReelsError extends ReelsState {
  final String message;
  final Completer<void>? refreshCompleter;

  const ReelsError(this.message, {this.refreshCompleter});
  @override
  List<Object?> get props => [message, refreshCompleter];
}

class ReelsLoaded extends ReelsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;
  final Completer<void>? refreshCompleter;

  const ReelsLoaded(
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

  ReelsLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
    Completer<void>? refreshCompleter,
  }) {
    return ReelsLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
      refreshCompleter: refreshCompleter,
    );
  }
}

class ReelsLoadingMore extends ReelsState {
  final List<PostEntity> posts;
  const ReelsLoadingMore({required this.posts});
  @override
  List<Object?> get props => [posts];
}

class ReelsLoadMoreError extends ReelsState {
  final String message;
  final List<PostEntity> posts;
  const ReelsLoadMoreError(this.message, {required this.posts});
  @override
  List<Object?> get props => [message, posts];
}
