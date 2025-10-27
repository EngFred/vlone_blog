import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/favorite_post_usecase.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritePostUseCase favoritePostUseCase;
  final RealtimeService realtimeService;

  StreamSubscription<Map<String, dynamic>>? _favoritesSub;
  String? _currentUserId;

  /// Posts that are currently being processed (prevents race conditions)
  final Set<String> _processingFavorites = {};

  FavoritesBloc({
    required this.favoritePostUseCase,
    required this.realtimeService,
  }) : super(FavoritesInitial()) {
    on<FavoritePostEvent>(_onFavoritePost);
    on<StartFavoritesStreamEvent>(_onStartFavoritesStream);
    on<StopFavoritesStreamEvent>(_onStopFavoritesStream);
    on<_RealtimeFavoriteReceivedEvent>(_onRealtimeFavoriteReceived);
  }

  Future<void> _onFavoritePost(
    FavoritePostEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    if (_processingFavorites.contains(event.postId)) {
      AppLogger.warning(
        'Dropping FavoritePostEvent for ${event.postId}: already processing.',
      );
      return;
    }

    _processingFavorites.add(event.postId);
    final optimisticDelta = event.isFavorited ? 1 : -1;

    AppLogger.info(
      'FavoritePostEvent → post:${event.postId} favorite:${event.isFavorited} (prev:${event.previousState})',
    );

    try {
      // Optimistic UI
      emit(
        FavoriteUpdated(
          postId: event.postId,
          userId: event.userId,
          isFavorited: event.isFavorited,
          delta: optimisticDelta,
        ),
      );

      final result = await favoritePostUseCase(
        FavoritePostParams(
          postId: event.postId,
          userId: event.userId,
          isFavorited: event.isFavorited,
        ),
      );

      result.fold(
        (failure) {
          final msg = failure.message;
          AppLogger.error('Favorite post failed: $msg');

          final lower = msg.toLowerCase();
          final isDuplicateKey =
              lower.contains('duplicate key') || lower.contains('23505');
          if (isDuplicateKey && event.isFavorited) {
            AppLogger.info(
              'Duplicate-key on favorite INSERT → treat as success.',
            );
            emit(
              FavoriteUpdated(
                postId: event.postId,
                userId: event.userId,
                isFavorited: true,
                delta: 0,
              ),
            );
            emit(
              FavoriteSuccess(
                postId: event.postId,
                userId: event.userId,
                isFavorited: true,
              ),
            );
          } else {
            emit(
              FavoriteError(
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
          AppLogger.info('Favorite operation succeeded for ${event.postId}');
          emit(
            FavoriteSuccess(
              postId: event.postId,
              userId: event.userId,
              isFavorited: event.isFavorited,
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error in _onFavoritePost: $e');
      emit(
        FavoriteError(
          postId: event.postId,
          message: e.toString(),
          shouldRevert: true,
          previousState: event.previousState,
          delta: optimisticDelta,
        ),
      );
    } finally {
      _processingFavorites.remove(event.postId);
    }
  }

  Future<void> _onStartFavoritesStream(
    StartFavoritesStreamEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    AppLogger.info(
      'FavoritesBloc: starting favorites subscription to RealtimeService',
    );
    _currentUserId = event.userId;

    await _favoritesSub?.cancel();

    _favoritesSub = realtimeService.onFavorite.listen(
      (favData) {
        try {
          final dynamic eventType = favData['event'];
          final isFavorited = eventType == 'INSERT' || eventType == 'insert';
          final postId =
              favData['post_id'] ?? favData['postId'] ?? favData['id'];
          final userId =
              favData['user_id'] ?? favData['userId'] ?? favData['actor_id'];

          if (postId is String && userId is String) {
            add(
              _RealtimeFavoriteReceivedEvent(
                postId: postId,
                userId: userId,
                isFavorited: isFavorited,
              ),
            );
          } else {
            AppLogger.warning(
              'FavoritesBloc: received favData with invalid fields: $favData',
            );
          }
        } catch (e) {
          AppLogger.error(
            'FavoritesBloc: error processing realtime favorite data: $e',
            error: e,
          );
        }
      },
      onError: (err) => AppLogger.error(
        'FavoritesBloc: RealtimeService.onFavorite error: $err',
        error: err,
      ),
    );

    emit(FavoritesStreamStarted());
  }

  Future<void> _onStopFavoritesStream(
    StopFavoritesStreamEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    AppLogger.info('FavoritesBloc: stopping favorites subscription');
    await _favoritesSub?.cancel();
    _favoritesSub = null;
    _currentUserId = null;
    emit(FavoritesStreamStopped());
  }

  void _onRealtimeFavoriteReceived(
    _RealtimeFavoriteReceivedEvent event,
    Emitter<FavoritesState> emit,
  ) {
    if (event.userId == _currentUserId) {
      AppLogger.info(
        'FavoritesBloc: realtime favorite for current user on post: ${event.postId}',
      );
      emit(
        FavoriteUpdated(
          postId: event.postId,
          userId: event.userId,
          isFavorited: event.isFavorited,
          delta: 0,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    AppLogger.info('Closing FavoritesBloc – cancelling subscription');
    await _favoritesSub?.cancel();
    return super.close();
  }
}
