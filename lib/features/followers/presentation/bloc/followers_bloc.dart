import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

part 'followers_event.dart';
part 'followers_state.dart';

class FollowersBloc extends Bloc<FollowersEvent, FollowersState> {
  final FollowUserUseCase followUserUseCase;
  final GetFollowersUseCase getFollowersUseCase;
  final GetFollowingUseCase getFollowingUseCase;

  FollowersBloc({
    required this.followUserUseCase,
    required this.getFollowersUseCase,
    required this.getFollowingUseCase,
  }) : super(FollowersInitial()) {
    on<FollowUserEvent>((event, emit) async {
      emit(FollowersLoading());
      final result = await followUserUseCase(
        FollowUserParams(
          followerId: event.followerId,
          followingId: event.followingId,
          isFollowing: event.isFollowing,
        ),
      );
      result.fold(
        (failure) => emit(FollowersError(failure.message)),
        (follower) => emit(UserFollowed(event.followingId, !event.isFollowing)),
      );
    });

    on<GetFollowersEvent>((event, emit) async {
      emit(FollowersLoading());
      final result = await getFollowersUseCase(
        GetFollowersParams(
          userId: event.userId,
          page: event.page,
          limit: event.limit,
        ),
      );
      result.fold(
        (failure) => emit(FollowersError(failure.message)),
        (users) => emit(FollowersLoaded(users)),
      );
    });

    on<GetFollowingEvent>((event, emit) async {
      emit(FollowersLoading());
      final result = await getFollowingUseCase(
        GetFollowingParams(
          userId: event.userId,
          page: event.page,
          limit: event.limit,
        ),
      );
      result.fold(
        (failure) => emit(FollowersError(failure.message)),
        (users) => emit(FollowingLoaded(users)),
      );
    });
  }
}
