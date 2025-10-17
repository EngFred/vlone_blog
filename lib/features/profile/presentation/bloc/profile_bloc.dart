import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
    on<GetProfileEvent>((event, emit) async {
      emit(ProfileLoading());
      final result = await getProfileUseCase(event.userId);
      result.fold(
        (failure) => emit(ProfileError(failure.message)),
        (profile) => emit(ProfileLoaded(profile)),
      );
    });

    on<UpdateProfileEvent>((event, emit) async {
      emit(ProfileLoading());
      final result = await updateProfileUseCase(
        UpdateProfileParams(
          userId: event.userId,
          bio: event.bio,
          profileImage: event.profileImage,
        ),
      );
      result.fold(
        (failure) => emit(ProfileError(failure.message)),
        (profile) => emit(ProfileLoaded(profile)),
      );
    });

    on<GetUserPostsEvent>((event, emit) async {
      emit(
        ProfileLoading(),
      ); // Could use a separate PostsLoading state if needed
      final result = await getUserPostsUseCase(
        GetUserPostsParams(
          userId: event.userId,
          page: event.page,
          limit: event.limit,
        ),
      );
      result.fold(
        (failure) => emit(ProfileError(failure.message)),
        (posts) => emit(UserPostsLoaded(posts)),
      );
    });
  }
}
