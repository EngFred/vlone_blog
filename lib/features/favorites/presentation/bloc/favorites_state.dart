part of 'favorites_bloc.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoriteUpdated extends FavoritesState {
  final String postId;
  final String userId;
  final bool isFavorited;

  const FavoriteUpdated({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
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

  const FavoriteError({
    required this.postId,
    required this.message,
    required this.shouldRevert,
    required this.previousState,
  });

  @override
  List<Object?> get props => [postId, message, shouldRevert, previousState];
}

class FavoritesStreamStarted extends FavoritesState {}

class FavoritesStreamStopped extends FavoritesState {}
