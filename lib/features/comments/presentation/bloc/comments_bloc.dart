import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/get_initial_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/load_more_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/stream_comments_usecase.dart';

part 'comments_event.dart';
part 'comments_state.dart';

class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  final AddCommentUseCase addCommentUseCase;
  final GetInitialCommentsUseCase getInitialCommentsUseCase;
  final LoadMoreCommentsUseCase loadMoreCommentsUseCase;
  final StreamCommentsUseCase streamCommentsUseCase;
  final CommentsRepository repository;
  final RealtimeService realtimeService;

  StreamSubscription? _commentsStreamSubscription;
  StreamSubscription? _rtCommentsSub;
  String? _currentPostId;

  static const int _pageSize = 20;
  bool _hasMore = true;
  DateTime? _lastCreatedAt;
  String? _lastId;

  CommentsBloc({
    required this.addCommentUseCase,
    required this.getInitialCommentsUseCase,
    required this.loadMoreCommentsUseCase,
    required this.streamCommentsUseCase,
    required this.repository,
    required this.realtimeService,
  }) : super(CommentsInitial()) {
    on<GetInitialCommentsEvent>(_onGetInitialComments);
    on<LoadMoreCommentsEvent>(_onLoadMoreComments);
    on<RefreshCommentsEvent>(_onRefreshComments);
    on<AddCommentEvent>(_onAddComment);
    on<StartCommentsStreamEvent>(_onStartCommentsStream);
    on<StopCommentsStreamEvent>(_onStopCommentsStream);
    on<_RealtimeCommentReceivedEvent>(_onRealtimeCommentReceived);
    // Legacy compatibility
    on<SubscribeToCommentsEvent>((event, emit) {
      add(StartCommentsStreamEvent(event.postId));
    });
    on<NewCommentsEvent>((event, emit) {
      if (state is CommentsLoaded) {
        final current = state as CommentsLoaded;
        emit(current.copyWith(comments: event.newComments));
      } else {
        emit(CommentsLoaded(comments: event.newComments, hasMore: _hasMore));
      }
    });
  }

  Future<void> _onGetInitialComments(
    GetInitialCommentsEvent event,
    Emitter<CommentsState> emit,
  ) async {
    AppLogger.info(
      'GetInitialCommentsEvent triggered for post: ${event.postId}',
    );
    emit(const CommentsLoading());
    final result = await getInitialCommentsUseCase(event.postId);
    result.fold(
      (failure) {
        final friendly = ErrorMessageMapper.mapToUserMessage(failure.message);
        AppLogger.error('Get initial comments failed: ${failure.message}');
        emit(CommentsError(friendly));
      },
      (rootComments) {
        // CHANGE: Reset pagination cursors on initial load.
        _lastCreatedAt = rootComments.isNotEmpty
            ? rootComments.last.createdAt
            : null;
        _lastId = rootComments.isNotEmpty ? rootComments.last.id : null;
        _hasMore = rootComments.length == _pageSize;
        AppLogger.info(
          'Initial comments loaded: ${rootComments.length} roots, hasMore: $_hasMore',
        );
        emit(CommentsLoaded(comments: rootComments, hasMore: _hasMore));
      },
    );
  }

  Future<void> _onLoadMoreComments(
    LoadMoreCommentsEvent event,
    Emitter<CommentsState> emit,
  ) async {
    // FIX 2a: Add null checks for cursors to prevent crash
    if (!_hasMore ||
        state is CommentsLoadingMore ||
        _lastCreatedAt == null ||
        _lastId == null) {
      return;
    }
    // Ensure we are in a loaded state to load more
    if (state is! CommentsLoaded) return;
    final currentState = state as CommentsLoaded;
    emit(currentState.copyWith(isLoadingMore: true, loadMoreError: null));
    final result = await loadMoreCommentsUseCase(
      LoadMoreCommentsParams(
        postId: event.postId,
        lastCreatedAt: _lastCreatedAt!,
        lastId: _lastId!,
        pageSize: _pageSize,
      ),
    );
    result.fold(
      (failure) {
        final friendly = ErrorMessageMapper.mapToUserMessage(failure.message);
        AppLogger.error('Load more comments failed: ${failure.message}');
        emit(
          currentState.copyWith(isLoadingMore: false, loadMoreError: friendly),
        );
      },
      (newRootComments) {
        // Append new roots to existing (chronological order: newer at top, older appended).
        final updatedComments = [...currentState.comments, ...newRootComments];
        _lastCreatedAt = newRootComments.isNotEmpty
            ? newRootComments.last.createdAt
            : null;
        _lastId = newRootComments.isNotEmpty ? newRootComments.last.id : null;
        _hasMore = newRootComments.length == _pageSize;
        AppLogger.info(
          'Loaded ${newRootComments.length} more roots, total: ${updatedComments.length}, hasMore: $_hasMore',
        );
        emit(
          CommentsLoaded(
            comments: updatedComments,
            hasMore: _hasMore,
            isLoadingMore: false,
          ),
        );
      },
    );
  }

  Future<void> _onRefreshComments(
    RefreshCommentsEvent event,
    Emitter<CommentsState> emit,
  ) async {
    //Reset pagination and reload initial.
    _hasMore = true;
    _lastCreatedAt = null;
    _lastId = null;
    add(GetInitialCommentsEvent(event.postId));
  }

  Future<void> _onAddComment(
    AddCommentEvent event,
    Emitter<CommentsState> emit,
  ) async {
    AppLogger.info('AddCommentEvent triggered for post: ${event.postId}');

    if (state is! CommentsLoaded) return;

    final currentState = state as CommentsLoaded;

    // Find parent if replying to a comment
    CommentEntity? parent;
    String? parentUsername;
    if (event.parentCommentId != null) {
      parent = _findCommentById(currentState.comments, event.parentCommentId!);
      if (parent != null) {
        parentUsername = parent.username;
      }
    }

    // Create temporary comment
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempComment = CommentEntity(
      id: tempId,
      postId: event.postId,
      userId: event.userId,
      username: event.username ?? 'You',
      avatarUrl: event.avatarUrl,
      text: event.text,
      createdAt: DateTime.now(),
      replies: [],
      repliesCount: null, // Use replies.length for count
      parentCommentId: event.parentCommentId,
      parentUsername: parentUsername,
    );

    // Optimistically add to the comments tree
    final updatedComments = _addOptimisticComment(
      currentState.comments,
      tempComment,
    );
    emit(currentState.copyWith(comments: updatedComments));

    // Perform the actual add operation
    final result = await addCommentUseCase(
      AddCommentParams(
        postId: event.postId,
        userId: event.userId,
        text: event.text,
        parentCommentId: event.parentCommentId,
      ),
    );

    result.fold(
      (failure) {
        final friendly = ErrorMessageMapper.mapToUserMessage(failure.message);
        AppLogger.error('Add comment failed: ${failure.message} -> $friendly');

        // Remove the temporary comment on failure
        final cleanedComments = _removeCommentById(updatedComments, tempId);
        emit(currentState.copyWith(comments: cleanedComments));
      },
      (_) {
        AppLogger.info('Comment added successfully. Stream will update UI.');
        // No need to do anything; real-time stream will refresh the list
      },
    );
  }

  Future<void> _onStartCommentsStream(
    StartCommentsStreamEvent event,
    Emitter<CommentsState> emit,
  ) async {
    // Prevent re-subscribing to the same post
    if (_currentPostId == event.postId && _commentsStreamSubscription != null) {
      return;
    }
    AppLogger.info(
      'Starting comments real-time stream for post: ${event.postId}',
    );
    _currentPostId = event.postId;
    await _commentsStreamSubscription?.cancel();
    _commentsStreamSubscription = repository
        .getCommentsStream(event.postId)
        .listen(
          (rootComments) {
            AppLogger.info(
              'Real-time: Comments updated for post: ${event.postId}',
            );
            add(_RealtimeCommentReceivedEvent(event.postId, rootComments));
          },
          onError: (error) {
            final friendly = ErrorMessageMapper.getErrorMessage(error);
            AppLogger.error(
              'Comments stream error (repo): $error -> $friendly',
              error: error,
            );
            emit(CommentsError(friendly));
          },
        );
    // CHANGE: Keep global realtime sub for notifications (unchanged).
    _rtCommentsSub?.cancel();
    _rtCommentsSub = realtimeService.onComment.listen(
      (commentData) {
        try {
          final postId =
              commentData['post_id'] ??
              commentData['postId'] ??
              commentData['post_id'];
          if (postId is String && postId == _currentPostId) {
            AppLogger.info(
              'RealtimeService: comment event detected for current post: $postId — refreshing via repo stream',
            );
          } else {
            AppLogger.info(
              'RealtimeService: comment event for other post: $postId',
            );
          }
        } catch (e) {
          AppLogger.error('Error handling realtime commentData: $e', error: e);
        }
      },
      onError: (err) => AppLogger.error(
        'CommentsBloc: RealtimeService.onComment error: $err',
        error: err,
      ),
    );
  }

  Future<void> _onStopCommentsStream(
    StopCommentsStreamEvent event,
    Emitter<CommentsState> emit,
  ) async {
    AppLogger.info('Stopping comments real-time stream');
    await _commentsStreamSubscription?.cancel();
    _commentsStreamSubscription = null;
    await _rtCommentsSub?.cancel();
    _rtCommentsSub = null;
    _currentPostId = null;
    //Reset pagination on stop (for re-init).
    _hasMore = true;
    _lastCreatedAt = null;
    _lastId = null;
    emit(const CommentsStreamStopped());
  }

  void _onRealtimeCommentReceived(
    _RealtimeCommentReceivedEvent event,
    Emitter<CommentsState> emit,
  ) {
    AppLogger.info('Realtime comments received for post: ${event.postId}');
    if (state is CommentsLoaded) {
      final current = state as CommentsLoaded;
      emit(current.copyWith(comments: event.comments));
    } else {
      // FIX 2b: Preserve the BLoC's _hasMore state, not the
      // constructor default (which is true), to prevent infinite loader.
      emit(CommentsLoaded(comments: event.comments, hasMore: _hasMore));
    }
  }

  // Helper: Find comment by ID in the tree
  CommentEntity? _findCommentById(List<CommentEntity> comments, String id) {
    for (final comment in comments) {
      if (comment.id == id) return comment;
      final found = _findCommentById(comment.replies, id);
      if (found != null) return found;
    }
    return null;
  }

  // Helper: Add optimistic comment to the tree
  List<CommentEntity> _addOptimisticComment(
    List<CommentEntity> comments,
    CommentEntity newComment,
  ) {
    if (newComment.parentCommentId == null) {
      // Add root comments to the beginning (newer first)
      return [newComment, ...comments];
    } else {
      // Recursively add to subtree
      return comments.map((c) => _addToSubtree(c, newComment)).toList();
    }
  }

  CommentEntity _addToSubtree(CommentEntity comment, CommentEntity newComment) {
    if (comment.id == newComment.parentCommentId) {
      // Add reply to the end (append new replies)
      final newReplies = [...comment.replies, newComment];
      final newRepliesCount = comment.repliesCount != null
          ? comment.repliesCount! + 1
          : null;
      return CommentEntity(
        id: comment.id,
        postId: comment.postId,
        userId: comment.userId,
        username: comment.username,
        avatarUrl: comment.avatarUrl,
        text: comment.text,
        createdAt: comment.createdAt,
        parentCommentId: comment.parentCommentId,
        parentUsername: comment.parentUsername,
        replies: newReplies,
        repliesCount: newRepliesCount,
      );
    } else {
      final newReplies = comment.replies
          .map((r) => _addToSubtree(r, newComment))
          .toList();
      if (newReplies.length == comment.replies.length &&
          newReplies.every((r) => comment.replies.contains(r))) {
        return comment; // No change, return original for performance
      }
      return CommentEntity(
        id: comment.id,
        postId: comment.postId,
        userId: comment.userId,
        username: comment.username,
        avatarUrl: comment.avatarUrl,
        text: comment.text,
        createdAt: comment.createdAt,
        parentCommentId: comment.parentCommentId,
        parentUsername: comment.parentUsername,
        replies: newReplies,
        repliesCount: comment.repliesCount,
      );
    }
  }

  // Helper: Remove comment by ID from the tree
  List<CommentEntity> _removeCommentById(
    List<CommentEntity> comments,
    String id,
  ) {
    return comments.where((c) => c.id != id).map((c) {
      final newReplies = _removeCommentById(c.replies, id);
      if (newReplies.length == c.replies.length) {
        return c; // No change
      }
      final newRepliesCount = c.repliesCount != null
          ? c.repliesCount! - 1
          : null;
      return CommentEntity(
        id: c.id,
        postId: c.postId,
        userId: c.userId,
        username: c.username,
        avatarUrl: c.avatarUrl,
        text: c.text,
        createdAt: c.createdAt,
        parentCommentId: c.parentCommentId,
        parentUsername: c.parentUsername,
        replies: newReplies,
        repliesCount: newRepliesCount,
      );
    }).toList();
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing CommentsBloc - cancelling subscription');
    _commentsStreamSubscription?.cancel();
    _rtCommentsSub?.cancel();
    return super.close();
  }
}
