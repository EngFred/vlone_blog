import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/stream_likes_usecase.dart';

part 'likes_event.dart';
part 'likes_state.dart';

class LikesBloc extends Bloc<LikesEvent, LikesState> {
  final LikePostUseCase likePostUseCase;
  final StreamLikesUseCase streamLikesUseCase;

  StreamSubscription? _likesSubscription;
  String? _currentUserId;

  LikesBloc({required this.likePostUseCase, required this.streamLikesUseCase})
    : super(LikesInitial()) {
    on<LikePostEvent>(_onLikePost);
    on<StartLikesStreamEvent>(_onStartLikesStream);
    on<StopLikesStreamEvent>(_onStopLikesStream);
    on<_RealtimeLikeReceivedEvent>(_onRealtimeLikeReceived);
  }

  Future<void> _onLikePost(
    LikePostEvent event,
    Emitter<LikesState> emit,
  ) async {
    AppLogger.info(
      'LikePostEvent triggered for post: ${event.postId}, like: ${event.isLiked}',
    );

    // Emit optimistic update
    emit(
      LikeUpdated(
        postId: event.postId,
        userId: event.userId,
        isLiked: event.isLiked,
      ),
    );

    final result = await likePostUseCase(
      LikePostParams(
        postId: event.postId,
        userId: event.userId,
        isLiked: event.isLiked,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.error('Like post failed: ${failure.message}');
        // Emit error with revert flag
        emit(
          LikeError(
            postId: event.postId,
            message: failure.message,
            shouldRevert: true,
            previousState: !event.isLiked,
          ),
        );
      },
      (_) {
        AppLogger.info('Post liked/unliked successfully');
        emit(
          LikeSuccess(
            postId: event.postId,
            userId: event.userId,
            isLiked: event.isLiked,
          ),
        );
      },
    );
  }

  Future<void> _onStartLikesStream(
    StartLikesStreamEvent event,
    Emitter<LikesState> emit,
  ) async {
    AppLogger.info('Starting likes real-time stream');
    _currentUserId = event.userId;

    await _likesSubscription?.cancel();

    _likesSubscription = streamLikesUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time like error: ${failure.message}'),
          (likeData) {
            final isLiked = likeData['event'] == 'INSERT';
            AppLogger.info(
              'Real-time: Like ${isLiked ? 'added' : 'removed'} on post: ${likeData['post_id']}',
            );
            add(
              _RealtimeLikeReceivedEvent(
                postId: likeData['post_id'] as String,
                userId: likeData['user_id'] as String,
                isLiked: isLiked,
              ),
            );
          },
        );
      },
      onError: (error) {
        AppLogger.error('Likes stream error: $error', error: error);
      },
    );

    emit(LikesStreamStarted());
  }

  Future<void> _onStopLikesStream(
    StopLikesStreamEvent event,
    Emitter<LikesState> emit,
  ) async {
    AppLogger.info('Stopping likes real-time stream');
    await _likesSubscription?.cancel();
    _likesSubscription = null;
    _currentUserId = null;
    emit(LikesStreamStopped());
  }

  void _onRealtimeLikeReceived(
    _RealtimeLikeReceivedEvent event,
    Emitter<LikesState> emit,
  ) {
    // Only emit if it's from the current user
    if (event.userId == _currentUserId) {
      AppLogger.info(
        'Real-time like update for current user on post: ${event.postId}',
      );
      emit(
        LikeUpdated(
          postId: event.postId,
          userId: event.userId,
          isLiked: event.isLiked,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing LikesBloc - cancelling subscription');
    _likesSubscription?.cancel();
    return super.close();
  }
}
