part of 'favorites_bloc.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoritesStreamStarted extends FavoritesState {}

class FavoritesStreamStopped extends FavoritesState {}

/// Optimistic update **and** server-driven correction
class FavoriteUpdated extends FavoritesState {
  final String postId;
  final String userId;
  final bool isFavorited;
  final int delta; // +1 / -1 for optimistic, 0 for server correction

  const FavoriteUpdated({
    required this.postId,
    required this.userId,
    required this.isFavorited,
    required this.delta,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited, delta];
}

/// Final success after the server confirmed the operation
class FavoriteSuccess extends FavoritesState {
  final String postId;
  final String userId;
  final bool isFavorited;

  const FavoriteSuccess({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

/// Something went wrong
class FavoriteError extends FavoritesState {
  final String postId;
  final String message;
  final bool shouldRevert;
  final bool previousState;
  final int delta; // the optimistic delta we applied

  const FavoriteError({
    required this.postId,
    required this.message,
    required this.shouldRevert,
    required this.previousState,
    required this.delta,
  });

  @override
  List<Object?> get props => [
    postId,
    message,
    shouldRevert,
    previousState,
    delta,
  ];
}
