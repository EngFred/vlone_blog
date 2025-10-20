import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
  }) : super(ProfileInitial()) {
    on<GetProfileDataEvent>((event, emit) async {
      emit(ProfileLoading());
      final profileResult = await getProfileUseCase(event.userId);
      profileResult.fold(
        (failure) => emit(ProfileError(failure.message)),
        (profile) => emit(ProfileDataLoaded(profile: profile)),
      );
    });

    on<UpdateProfileEvent>((event, emit) async {
      // Reload profile after update
      add(GetProfileDataEvent(event.userId));
    });
  }
}
