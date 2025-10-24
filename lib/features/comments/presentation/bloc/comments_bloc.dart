import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
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

  StreamSubscription? _commentsStreamSubscription;
  String? _currentPostId;

  CommentsBloc({
    required this.addCommentUseCase,
    required this.getCommentsUseCase,
    required this.streamCommentsUseCase,
    required this.repository,
  }) : super(CommentsInitial()) {
    on<GetCommentsEvent>(_onGetComments);
    on<AddCommentEvent>(_onAddComment);
    on<StartCommentsStreamEvent>(_onStartCommentsStream);
    on<StopCommentsStreamEvent>(_onStopCommentsStream);
    on<_RealtimeCommentReceivedEvent>(_onRealtimeCommentReceived);

    // Keep legacy event for backwards compatibility
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
        emit(CommentsError(failure.message));
      },
      (_) {
        AppLogger.info('Comment added successfully');
        emit(CommentAdded(event.postId));
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

    // Use repository stream (existing implementation)
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
            AppLogger.error('Comments stream error: $error', error: error);
            emit(CommentsError(error.toString()));
          },
        );

    // Also subscribe to global comments stream for notification
    streamCommentsUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time comment error: ${failure.message}'),
          (commentData) {
            final postId = commentData['post_id'] as String;
            if (postId == _currentPostId) {
              AppLogger.info('Real-time: New comment on current post: $postId');
            }
          },
        );
      },
      onError: (error) {
        AppLogger.error('Global comments stream error: $error', error: error);
      },
    );

    emit(CommentsStreamStarted(event.postId));
  }

  Future<void> _onStopCommentsStream(
    StopCommentsStreamEvent event,
    Emitter<CommentsState> emit,
  ) async {
    AppLogger.info('Stopping comments real-time stream');
    await _commentsStreamSubscription?.cancel();
    _commentsStreamSubscription = null;
    _currentPostId = null;
    emit(CommentsStreamStopped());
  }

  void _onRealtimeCommentReceived(
    _RealtimeCommentReceivedEvent event,
    Emitter<CommentsState> emit,
  ) {
    AppLogger.info('Real-time comments received for post: ${event.postId}');
    emit(CommentsLoaded(event.comments));
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing CommentsBloc - cancelling subscription');
    _commentsStreamSubscription?.cancel();
    return super.close();
  }
}
