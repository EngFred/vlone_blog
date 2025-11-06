part of 'favorites_bloc.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoritesStreamStarted extends FavoritesState {}

class FavoritesStreamStopped extends FavoritesState {}

class FavoriteUpdated extends FavoritesState {
  final String postId;
  final String userId;
  final bool isFavorited;
  final int delta;

  const FavoriteUpdated({
    required this.postId,
    required this.userId,
    required this.isFavorited,
    required this.delta,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited, delta];
}

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

class FavoriteError extends FavoritesState {
  final String postId;
  final String message;
  final bool shouldRevert;
  final bool previousState;
  final int delta;

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
