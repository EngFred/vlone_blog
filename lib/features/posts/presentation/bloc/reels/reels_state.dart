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
  const ReelsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ReelsLoaded extends ReelsState {
  final List<PostEntity> posts;
  final bool hasMore;
  final bool isRealtimeActive;

  const ReelsLoaded(
    this.posts, {
    this.hasMore = true,
    this.isRealtimeActive = false,
  });

  @override
  List<Object?> get props => [posts, hasMore, isRealtimeActive];

  ReelsLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isRealtimeActive,
  }) {
    return ReelsLoaded(
      posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
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
