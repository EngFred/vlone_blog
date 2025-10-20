import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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
    on<GetProfileDataEvent>(_onGetProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
  }

  Future<void> _onGetProfile(
    GetProfileDataEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final result = await getProfileUseCase(event.userId);
    result.fold(
      (failure) {
        AppLogger.error('GetProfile failed: ${failure.message}');
        emit(ProfileError(failure.message));
      },
      (profile) {
        emit(ProfileDataLoaded(profile: profile));
      },
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info('UpdateProfileEvent: ${event.userId}');
    // Emit loading to indicate update in progress
    emit(ProfileLoading());

    final result = await updateProfileUseCase(
      UpdateProfileParams(
        userId: event.userId,
        username: event.username,
        bio: event.bio,
        profileImage: event.profileImage,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.error('UpdateProfile failed: ${failure.message}');
        emit(ProfileError(failure.message));
      },
      (profile) {
        AppLogger.info('Profile updated successfully: ${profile.id}');
        emit(ProfileDataLoaded(profile: profile));
      },
    );
  }
}
