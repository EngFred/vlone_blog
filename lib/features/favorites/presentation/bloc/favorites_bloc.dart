import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/favorite_post_usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/stream_favorites_usecase.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritePostUseCase favoritePostUseCase;
  final StreamFavoritesUseCase streamFavoritesUseCase;

  StreamSubscription? _favoritesSubscription;
  String? _currentUserId;

  FavoritesBloc({
    required this.favoritePostUseCase,
    required this.streamFavoritesUseCase,
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
    AppLogger.info(
      'FavoritePostEvent triggered for post: ${event.postId}, favorite: ${event.isFavorited}',
    );

    // Emit optimistic update
    emit(
      FavoriteUpdated(
        postId: event.postId,
        userId: event.userId,
        isFavorited: event.isFavorited,
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
        AppLogger.error('Favorite post failed: ${failure.message}');
        // Emit error with revert flag
        emit(
          FavoriteError(
            postId: event.postId,
            message: failure.message,
            shouldRevert: true,
            previousState: !event.isFavorited,
          ),
        );
      },
      (_) {
        AppLogger.info('Post favorited/unfavorited successfully');
        emit(
          FavoriteSuccess(
            postId: event.postId,
            userId: event.userId,
            isFavorited: event.isFavorited,
          ),
        );
      },
    );
  }

  Future<void> _onStartFavoritesStream(
    StartFavoritesStreamEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    AppLogger.info('Starting favorites real-time stream');
    _currentUserId = event.userId;

    await _favoritesSubscription?.cancel();

    _favoritesSubscription = streamFavoritesUseCase(NoParams()).listen(
      (either) {
        either.fold(
          (failure) =>
              AppLogger.error('Real-time favorite error: ${failure.message}'),
          (favoriteData) {
            final isFavorited = favoriteData['event'] == 'INSERT';
            AppLogger.info(
              'Real-time: Favorite ${isFavorited ? 'added' : 'removed'} on post: ${favoriteData['post_id']}',
            );
            add(
              _RealtimeFavoriteReceivedEvent(
                postId: favoriteData['post_id'] as String,
                userId: favoriteData['user_id'] as String,
                isFavorited: isFavorited,
              ),
            );
          },
        );
      },
      onError: (error) {
        AppLogger.error('Favorites stream error: $error', error: error);
      },
    );

    emit(FavoritesStreamStarted());
  }

  Future<void> _onStopFavoritesStream(
    StopFavoritesStreamEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    AppLogger.info('Stopping favorites real-time stream');
    await _favoritesSubscription?.cancel();
    _favoritesSubscription = null;
    _currentUserId = null;
    emit(FavoritesStreamStopped());
  }

  void _onRealtimeFavoriteReceived(
    _RealtimeFavoriteReceivedEvent event,
    Emitter<FavoritesState> emit,
  ) {
    // Only emit if it's from the current user
    if (event.userId == _currentUserId) {
      AppLogger.info(
        'Real-time favorite update for current user on post: ${event.postId}',
      );
      emit(
        FavoriteUpdated(
          postId: event.postId,
          userId: event.userId,
          isFavorited: event.isFavorited,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing FavoritesBloc - cancelling subscription');
    _favoritesSubscription?.cancel();
    return super.close();
  }
}
