part of 'favorites_bloc.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

/// User tapped the favorite button
class FavoritePostEvent extends FavoritesEvent {
  final String postId;
  final String userId;
  final bool isFavorited;
  final bool previousState;

  const FavoritePostEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
    required this.previousState,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited, previousState];
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

/// Internal – comes from the Supabase realtime channel
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
