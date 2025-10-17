part of 'favorites_bloc.dart';

abstract class FavoritesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AddFavoriteEvent extends FavoritesEvent {
  final String postId;
  final String userId;
  final bool isFavorited;

  AddFavoriteEvent({
    required this.postId,
    required this.userId,
    required this.isFavorited,
  });

  @override
  List<Object?> get props => [postId, userId, isFavorited];
}

class GetFavoritesEvent extends FavoritesEvent {
  final String userId;
  final int page;
  final int limit;

  GetFavoritesEvent({required this.userId, this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [userId, page, limit];
}
