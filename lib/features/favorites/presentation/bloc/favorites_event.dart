part of 'favorites_bloc.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class FavoritePostEvent extends FavoritesEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  const FavoritePostEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

class StartFavoritesStreamEvent extends FavoritesEvent {
  final String userId;

  const StartFavoritesStreamEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class StopFavoritesStreamEvent extends FavoritesEvent {
  const StopFavoritesStreamEvent();
}

// Internal event for real-time updates
class _RealtimeFavoriteReceivedEvent extends FavoritesEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  const _RealtimeFavoriteReceivedEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}
