import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:vlone_blog_app/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final AddFavoriteUseCase addFavoriteUseCase;
  final GetFavoritesUseCase getFavoritesUseCase;

  FavoritesBloc({
    required this.addFavoriteUseCase,
    required this.getFavoritesUseCase,
  }) : super(FavoritesInitial()) {
    on<AddFavoriteEvent>((event, emit) async {
      emit(FavoritesLoading());
      final result = await addFavoriteUseCase(
        AddFavoriteParams(
          postId: event.postId,
          userId: event.userId,
          isFavorited: event.isFavorited,
        ),
      );
      result.fold((failure) => emit(FavoritesError(failure.message)), (
        favorite,
      ) {
        if (event.isFavorited) {
          emit(FavoriteAdded(favorite.postId, event.isFavorited));
        } else {
          emit(FavoriteRemoved(favorite.postId));
        }
      });
    });

    on<GetFavoritesEvent>((event, emit) async {
      emit(FavoritesLoading());
      final result = await getFavoritesUseCase(
        GetFavoritesParams(userId: event.userId),
      );
      result.fold(
        (failure) => emit(FavoritesError(failure.message)),
        (posts) => emit(FavoritesLoaded(posts)),
      );
    });
  }
}
