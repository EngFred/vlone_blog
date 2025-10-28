import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/get_comments_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/stream_comments_usecase.dart';

part 'comments_event.dart';
part 'comments_state.dart';

class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  final AddCommentUseCase addCommentUseCase;
  final GetCommentsUseCase getCommentsUseCase;
  final StreamCommentsUseCase streamCommentsUseCase;
  final CommentsRepository repository;
  final RealtimeService realtimeService;

  StreamSubscription? _commentsStreamSubscription;
  StreamSubscription? _rtCommentsSub;
  String? _currentPostId;

  CommentsBloc({
    required this.addCommentUseCase,
    required this.getCommentsUseCase,
    required this.streamCommentsUseCase,
    required this.repository,
    required this.realtimeService,
  }) : super(CommentsInitial()) {
    on<GetCommentsEvent>(_onGetComments);
    on<AddCommentEvent>(_onAddComment);
    on<StartCommentsStreamEvent>(_onStartCommentsStream);
    on<StopCommentsStreamEvent>(_onStopCommentsStream);
    on<_RealtimeCommentReceivedEvent>(_onRealtimeCommentReceived);

    // Legacy compatibility
    on<SubscribeToCommentsEvent>((event, emit) {
      add(StartCommentsStreamEvent(event.postId));
    });

    on<NewCommentsEvent>((event, emit) {
      emit(CommentsLoaded(event.newComments));
    });
  }

  Future<void> _onGetComments(
    GetCommentsEvent event,
    Emitter<CommentsState> emit,
  ) async {
    AppLogger.info('GetCommentsEvent triggered for post: ${event.postId}');
    emit(CommentsLoading());

    final result = await getCommentsUseCase(event.postId);
    result.fold(
      (failure) {
        AppLogger.error('Get comments failed: ${failure.message}');
        emit(CommentsError(failure.message));
      },
      (rootComments) {
        AppLogger.info('Comments loaded: ${rootComments.length} comments');
        emit(CommentsLoaded(rootComments));
      },
    );
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
        // ✅ FIX: Removed the emit(CommentsError(failure.message));
        // Emitting a general error state here is bad UX, as it
        // replaces the entire comment list with an error message
        // just because a *new* comment failed to send.
        // A better pattern would be to emit a specific failure state
        // (like CommentAddFailed) and use a BlocListener in the UI
        // to show a SnackBar, while the main list remains visible.
        // For now, just logging the error is safer.
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

    // Keep per-post repository stream for accurate comment tree updates
    emit(CommentsLoading());

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

    // Additionally, subscribe to the unified global comments stream from RealtimeService.
    // This lets the app receive comment notifications that may be produced elsewhere.
    _rtCommentsSub?.cancel();
    _rtCommentsSub = realtimeService.onComment.listen(
      (commentData) {
        try {
          // commentData expected to contain 'post_id' and 'comment' or similar
          final postId =
              commentData['post_id'] ??
              commentData['postId'] ??
              commentData['post_id'];
          if (postId is String && postId == _currentPostId) {
            // Depending on the shape you emit from server, you might get a full comment object or a map.
            // Here we rely on repository stream to carry the canonical tree; this global stream can be used
            // for lightweight notifications or incremental updates. We'll trigger a reload for simplicity.
            AppLogger.info(
              'RealtimeService: comment event detected for current post: $postId — refreshing via repo stream',
            );
            // Let repo stream drive UI; no manual merge here.
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

    // Do not emit CommentsStreamStarted here — repo stream will emit CommentsLoaded shortly.
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
    emit(CommentsStreamStopped());
  }

  void _onRealtimeCommentReceived(
    _RealtimeCommentReceivedEvent event,
    Emitter<CommentsState> emit,
  ) {
    AppLogger.info('Realtime comments received for post: ${event.postId}');
    emit(CommentsLoaded(event.comments));
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing CommentsBloc - cancelling subscription');
    _commentsStreamSubscription?.cancel();
    _rtCommentsSub?.cancel();
    return super.close();
  }
}
