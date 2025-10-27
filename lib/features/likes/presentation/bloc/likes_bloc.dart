import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/like_post_usecase.dart';

part 'likes_event.dart';
part 'likes_state.dart';

class LikesBloc extends Bloc<LikesEvent, LikesState> {
  final LikePostUseCase likePostUseCase;
  final RealtimeService realtimeService;

  StreamSubscription<Map<String, dynamic>>? _likesSub;
  String? _currentUserId;

  // Track posts currently being processed to avoid concurrent conflicting calls.
  final Set<String> _processingPosts = {};

  LikesBloc({required this.likePostUseCase, required this.realtimeService})
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
    if (_processingPosts.contains(event.postId)) {
      AppLogger.warning(
        'Dropping LikePostEvent for ${event.postId}: already processing.',
      );
      return;
    }

    _processingPosts.add(event.postId);

    final optimisticDelta = event.isLiked ? 1 : -1;
    AppLogger.info(
      'LikePostEvent triggered for post: ${event.postId}, like: ${event.isLiked} (previous UI: ${event.previousState})',
    );

    try {
      // Emit optimistic update centrally (includes delta)
      emit(
        LikeUpdated(
          postId: event.postId,
          userId: event.userId,
          isLiked: event.isLiked,
          delta: optimisticDelta,
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
          final msg = failure.message;
          AppLogger.error('Like post failed: $msg');

          final lower = msg.toLowerCase();
          final isDuplicateKey =
              lower.contains('duplicate key') || lower.contains('23505');
          if (isDuplicateKey && event.isLiked) {
            AppLogger.info(
              'Duplicate-key detected on like insert: treating as idempotent success.',
            );
            emit(
              LikeUpdated(
                postId: event.postId,
                userId: event.userId,
                isLiked: true,
                delta: 0,
              ),
            );
            emit(
              LikeSuccess(
                postId: event.postId,
                userId: event.userId,
                isLiked: true,
              ),
            );
          } else {
            emit(
              LikeError(
                postId: event.postId,
                message: msg,
                shouldRevert: true,
                previousState: event.previousState,
                delta: optimisticDelta,
              ),
            );
          }
        },
        (_) {
          AppLogger.info('Like/unlike successful for post: ${event.postId}');
          emit(
            LikeSuccess(
              postId: event.postId,
              userId: event.userId,
              isLiked: event.isLiked,
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error in _onLikePost: $e');
      emit(
        LikeError(
          postId: event.postId,
          message: e.toString(),
          shouldRevert: true,
          previousState: event.previousState,
          delta: optimisticDelta,
        ),
      );
    } finally {
      _processingPosts.remove(event.postId);
    }
  }

  Future<void> _onStartLikesStream(
    StartLikesStreamEvent event,
    Emitter<LikesState> emit,
  ) async {
    AppLogger.info('LikesBloc: starting likes subscription to RealtimeService');
    _currentUserId = event.userId;

    // Cancel previous subscription if any
    await _likesSub?.cancel();

    _likesSub = realtimeService.onLike.listen(
      (likeData) {
        try {
          final dynamic eventType = likeData['event'];
          final isLiked = eventType == 'INSERT' || eventType == 'insert';
          final postId =
              likeData['post_id'] ?? likeData['postId'] ?? likeData['id'];
          final userId =
              likeData['user_id'] ?? likeData['userId'] ?? likeData['actor_id'];

          if (postId is String && userId is String) {
            add(
              _RealtimeLikeReceivedEvent(
                postId: postId,
                userId: userId,
                isLiked: isLiked,
              ),
            );
          } else {
            AppLogger.warning(
              'LikesBloc: received likeData with invalid fields: $likeData',
            );
          }
        } catch (e) {
          AppLogger.error(
            'LikesBloc: error processing realtime like data: $e',
            error: e,
          );
        }
      },
      onError: (err) => AppLogger.error(
        'LikesBloc: RealtimeService.onLike error: $err',
        error: err,
      ),
    );

    emit(LikesStreamStarted());
  }

  Future<void> _onStopLikesStream(
    StopLikesStreamEvent event,
    Emitter<LikesState> emit,
  ) async {
    AppLogger.info('LikesBloc: stopping likes subscription');
    await _likesSub?.cancel();
    _likesSub = null;
    _currentUserId = null;
    emit(LikesStreamStopped());
  }

  void _onRealtimeLikeReceived(
    _RealtimeLikeReceivedEvent event,
    Emitter<LikesState> emit,
  ) {
    // Only act if this affects the current user
    if (event.userId == _currentUserId) {
      AppLogger.info(
        'LikesBloc: realtime like for current user on post: ${event.postId}',
      );
      emit(
        LikeUpdated(
          postId: event.postId,
          userId: event.userId,
          isLiked: event.isLiked,
          delta: 0,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing LikesBloc - cancelling subscription');
    _likesSub?.cancel();
    return super.close();
  }
}
