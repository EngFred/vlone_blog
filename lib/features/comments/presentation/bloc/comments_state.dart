part of 'comments_bloc.dart';

abstract class CommentsState extends Equatable {
  const CommentsState();

  @override
  List<Object?> get props => [];
}

class CommentsInitial extends CommentsState {}

class CommentsLoading extends CommentsState {
  const CommentsLoading();
}

// New: For load-more spinner.
class CommentsLoadingMore extends CommentsState {}

// Updated: Loaded with pagination fields.
class CommentsLoaded extends CommentsState {
  final List<CommentEntity> comments;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;

  const CommentsLoaded({
    required this.comments,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  CommentsLoaded copyWith({
    List<CommentEntity>? comments,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
  }) {
    return CommentsLoaded(
      comments: comments ?? this.comments,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError ?? this.loadMoreError,
    );
  }

  @override
  List<Object?> get props => [comments, hasMore, isLoadingMore, loadMoreError];
}

class CommentsError extends CommentsState {
  final String message;

  const CommentsError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentAdded extends CommentsState {
  final String postId;

  const CommentAdded(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CommentsStreamStarted extends CommentsState {
  final String postId;

  const CommentsStreamStarted(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CommentsStreamStopped extends CommentsState {
  const CommentsStreamStopped();
}
