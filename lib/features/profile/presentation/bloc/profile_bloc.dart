import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_user_posts_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final GetUserPostsUseCase getUserPostsUseCase;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
    required this.getUserPostsUseCase,
  }) : super(ProfileInitial()) {
    on<GetProfileDataEvent>((event, emit) async {
      // 1. Show a full-page loader only for the profile header.
      emit(ProfileLoading());

      // 2. Fetch the profile data first.
      final profileResult = await getProfileUseCase(event.userId);

      await profileResult.fold(
        (failure) async => emit(ProfileError(failure.message)),
        (profile) async {
          // 3. SUCCESS! Emit a state with the loaded profile and set posts to loading.
          // The UI will now show the header and a loader for the posts.
          emit(ProfileDataLoaded(profile: profile, arePostsLoading: true));

          // 4. Now, fetch the user's posts.
          final postsResult = await getUserPostsUseCase(
            GetUserPostsParams(userId: event.userId, page: 1),
          );

          // 5. Get the current state to update it with post data.
          if (state is ProfileDataLoaded) {
            final currentState = state as ProfileDataLoaded;
            postsResult.fold(
              (failure) => emit(
                currentState.copyWith(
                  arePostsLoading: false,
                  postsError: failure.message,
                ),
              ),
              (posts) => emit(
                currentState.copyWith(arePostsLoading: false, posts: posts),
              ),
            );
          }
        },
      );
    });

    on<UpdateProfileEvent>((event, emit) async {
      // While updating, we can just reload everything.
      add(GetProfileDataEvent(event.userId));
    });
  }
}
