part of 'favorites_bloc.dart';

abstract class FavoritesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<PostEntity> posts;

  FavoritesLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class FavoriteAdded extends FavoritesState {
  final String postId;
  final bool isFavorited;

  FavoriteAdded(this.postId, this.isFavorited);

  @override
  List<Object?> get props => [postId, isFavorited];
}

class FavoriteRemoved extends FavoritesState {
  final String postId;

  FavoriteRemoved(this.postId);

  @override
  List<Object?> get props => [postId];
}

class FavoritesError extends FavoritesState {
  final String message;

  FavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}
