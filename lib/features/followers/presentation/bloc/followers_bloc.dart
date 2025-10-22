// import 'package:bloc/bloc.dart';
// import 'package:equatable/equatable.dart';
// import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
// import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
// import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
// import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

// part 'followers_event.dart';
// part 'followers_state.dart';

// class FollowersBloc extends Bloc<FollowersEvent, FollowersState> {
//   final FollowUserUseCase followUserUseCase;
//   final GetFollowersUseCase getFollowersUseCase;
//   final GetFollowingUseCase getFollowingUseCase;

//   FollowersBloc({
//     required this.followUserUseCase,
//     required this.getFollowersUseCase,
//     required this.getFollowingUseCase,
//   }) : super(FollowersInitial()) {
//     on<FollowUserEvent>((event, emit) async {
//       // Don't emit loading state - just emit the result
//       final result = await followUserUseCase(
//         FollowUserParams(
//           followerId: event.followerId,
//           followingId: event.followingId,
//           isFollowing: event.isFollowing,
//         ),
//       );
//       result.fold(
//         (failure) => emit(FollowersError(failure.message)),
//         (follower) => emit(UserFollowed(event.followingId, event.isFollowing)),
//       );
//     });

//     on<GetFollowersEvent>((event, emit) async {
//       emit(FollowersLoading());
//       final result = await getFollowersUseCase(
//         GetFollowersParams(
//           userId: event.userId,
//           currentUserId: event.currentUserId,
//         ),
//       );
//       result.fold(
//         (failure) => emit(FollowersError(failure.message)),
//         (users) => emit(FollowersLoaded(users)),
//       );
//     });

//     on<GetFollowingEvent>((event, emit) async {
//       emit(FollowersLoading());
//       final result = await getFollowingUseCase(
//         GetFollowingParams(
//           userId: event.userId,
//           currentUserId: event.currentUserId,
//         ),
//       );
//       result.fold(
//         (failure) => emit(FollowersError(failure.message)),
//         (users) => emit(FollowingLoaded(users)),
//       );
//     });
//   }
// }

// Update features/followers/presentation/bloc/followers_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/follow_user_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_followers_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_following_usecase.dart';
import 'package:vlone_blog_app/features/followers/domain/usecases/get_follow_status_usecase.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

part 'followers_event.dart';
part 'followers_state.dart';

class FollowersBloc extends Bloc<FollowersEvent, FollowersState> {
  final FollowUserUseCase followUserUseCase;
  final GetFollowersUseCase getFollowersUseCase;
  final GetFollowingUseCase getFollowingUseCase;
  final GetFollowStatusUseCase getFollowStatusUseCase;

  FollowersBloc({
    required this.followUserUseCase,
    required this.getFollowersUseCase,
    required this.getFollowingUseCase,
    required this.getFollowStatusUseCase,
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
        (follower) => emit(UserFollowed(event.followingId, event.isFollowing)),
      );
    });

    on<GetFollowersEvent>((event, emit) async {
      emit(FollowersLoading());
      final result = await getFollowersUseCase(
        GetFollowersParams(
          userId: event.userId,
          currentUserId: event.currentUserId,
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
          currentUserId: event.currentUserId,
        ),
      );
      result.fold(
        (failure) => emit(FollowersError(failure.message)),
        (users) => emit(FollowingLoaded(users)),
      );
    });

    on<GetFollowStatusEvent>((event, emit) async {
      emit(FollowersLoading());
      final result = await getFollowStatusUseCase(
        GetFollowStatusParams(
          followerId: event.followerId,
          followingId: event.followingId,
        ),
      );
      result.fold(
        (failure) => emit(FollowersError(failure.message)),
        (isFollowing) =>
            emit(FollowStatusLoaded(event.followingId, isFollowing)),
      );
    });
  }
}
