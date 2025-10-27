import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/like_post_usecase.dart';
import 'package:vlone_blog_app/features/likes/domain/usecases/stream_likes_usecase.dart';

part 'likes_event.dart';
part 'likes_state.dart';

class LikesBloc extends Bloc<LikesEvent, LikesState> {
  final LikePostUseCase likePostUseCase;
  final StreamLikesUseCase streamLikesUseCase;

  StreamSubscription? _likesSubscription;
  String? _currentUserId;

  // ================== FIX ==================
  // This Set will track which post IDs are currently being processed.
  final Set<String> _processingPosts = {};
  // ================ END FIX ================

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
    // ================== FIX ==================
    // If we are already processing a like/unlike for this post, drop the event.
    if (_processingPosts.contains(event.postId)) {
      AppLogger.warning(
        'Dropping LikePostEvent for ${event.postId}: already processing.',
      );
      return;
    }
    // ================ END FIX ================

    try {
      // ================== FIX ==================
      // Add this post to the set to "lock" it.
      _processingPosts.add(event.postId);
      // ================ END FIX ================

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
    } catch (e) {
      // Handle any unexpected errors
      AppLogger.error('Unexpected error in _onLikePost: $e');
      emit(
        LikeError(
          postId: event.postId,
          message: e.toString(),
          shouldRevert: true,
          previousState: !event.isLiked,
        ),
      );
    } finally {
      // ================== FIX ==================
      // ALWAYS remove the post from the set, whether it succeeded or failed.
      // This "unlocks" it for the next event.
      _processingPosts.remove(event.postId);
      // ================ END FIX ================
    }
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

            // --- SAFELY PARSE THE DATA ---
            final postId = likeData['post_id'];
            final userId = likeData['user_id'];

            AppLogger.info(
              'Real-time: Like ${isLiked ? 'added' : 'removed'} on post: $postId',
            );

            // --- ADD NULL CHECK TO PREVENT CRASH ---
            if (postId is String && userId is String) {
              // Only proceed if data is valid
              add(
                _RealtimeLikeReceivedEvent(
                  postId: postId, // No 'as String' needed now
                  userId: userId, // No 'as String' needed now
                  isLiked: isLiked,
                ),
              );
            } else {
              // Log the bad data but DO NOT crash
              AppLogger.warning(
                'Real-time like event received with null or invalid data. PostID: $postId, UserID: $userId. Skipping event.',
              );
            }
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
