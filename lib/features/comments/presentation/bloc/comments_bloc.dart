import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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

  // CHANGE: Added pagination state (mirrors posts/notifications).
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
      emit(CommentsLoaded(comments: event.newComments));
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
        AppLogger.error('Get initial comments failed: ${failure.message}');
        emit(CommentsError(failure.message));
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
    if (!_hasMore || state is CommentsLoadingMore) return;

    final currentState = state as CommentsLoaded;
    emit(currentState.copyWith(isLoadingMore: true, loadMoreError: null));

    final result = await loadMoreCommentsUseCase(
      LoadMoreCommentsParams(
        postId: _currentPostId!,
        lastCreatedAt: _lastCreatedAt!,
        lastId: _lastId!,
        pageSize: _pageSize,
      ),
    );
    result.fold(
      (failure) {
        AppLogger.error('Load more comments failed: ${failure.message}');
        emit(
          currentState.copyWith(
            isLoadingMore: false,
            loadMoreError: failure.message,
          ),
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
    // CHANGE: Reset pagination and reload initial.
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
        AppLogger.error('Add comment failed: ${failure.message}');
        // Unchanged: Log only—no full error state to avoid nuking list.
      },
      (_) {
        AppLogger.info('Comment added successfully. Stream will update UI.');
      },
    );
  }

  Future<void> _onStartCommentsStream(
    StartCommentsStreamEvent event,
    Emitter<CommentsState> emit,
  ) async {
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
            AppLogger.error(
              'Comments stream error (repo): $error',
              error: error,
            );
            emit(CommentsError(error.toString()));
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

    //No initial emit—let GetInitialCommentsEvent drive pagination load.
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
    // CHANGE: Preserve hasMore etc. from current state.
    if (state is CommentsLoaded) {
      final current = state as CommentsLoaded;
      emit(current.copyWith(comments: event.comments));
    } else {
      emit(CommentsLoaded(comments: event.comments));
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing CommentsBloc - cancelling subscription');
    _commentsStreamSubscription?.cancel();
    _rtCommentsSub?.cancel();
    return super.close();
  }
}
