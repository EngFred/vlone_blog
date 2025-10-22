import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/stream_profile_updates_usecase.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final StreamProfileUpdatesUseCase streamProfileUpdatesUseCase;

  // Stream subscription for real-time
  StreamSubscription? _profileUpdatesSubscription;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
    required this.streamProfileUpdatesUseCase,
  }) : super(ProfileInitial()) {
    on<GetProfileDataEvent>(_onGetProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<StartProfileRealtimeEvent>(_onStartProfileRealtime);
    on<StopProfileRealtimeEvent>(_onStopProfileRealtime);
    on<_RealtimeProfileUpdatedEvent>(_onRealtimeProfileUpdated);
  }

  Future<void> _onGetProfile(
    GetProfileDataEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final result = await getProfileUseCase(event.userId);
    result.fold(
      (failure) {
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('GetProfile failed: $friendlyMessage');
        emit(ProfileError(friendlyMessage));
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
        final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
        AppLogger.error('UpdateProfile failed: $friendlyMessage');
        emit(ProfileError(friendlyMessage));
      },
      (profile) {
        AppLogger.info('Profile updated successfully: ${profile.id}');
        emit(ProfileDataLoaded(profile: profile));
      },
    );
  }

  Future<void> _onStartProfileRealtime(
    StartProfileRealtimeEvent event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info(
      'Starting real-time profile updates for user: ${event.userId}',
    );

    await _profileUpdatesSubscription?.cancel();

    _profileUpdatesSubscription = streamProfileUpdatesUseCase(event.userId)
        .listen(
          (either) {
            either.fold(
              (failure) => AppLogger.error(
                'Real-time profile update error: ${failure.message}',
              ),
              (updateData) {
                AppLogger.info(
                  'Real-time: Profile update received for: ${updateData['id']}',
                );
                add(_RealtimeProfileUpdatedEvent(updateData));
              },
            );
          },
          onError: (error) {
            AppLogger.error(
              'Profile updates stream error: $error',
              error: error,
            );
          },
        );
  }

  Future<void> _onStopProfileRealtime(
    StopProfileRealtimeEvent event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info('Stopping real-time profile updates');
    await _profileUpdatesSubscription?.cancel();
    _profileUpdatesSubscription = null;
  }

  void _onRealtimeProfileUpdated(
    _RealtimeProfileUpdatedEvent event,
    Emitter<ProfileState> emit,
  ) {
    final currentState = state;
    if (currentState is ProfileDataLoaded) {
      // Create updated profile from data
      final updatedProfile = ProfileModel.fromMap(event.updateData).toEntity();
      emit(ProfileDataLoaded(profile: updatedProfile));
      AppLogger.info(
        'Profile updated in real-time for user: ${updatedProfile.id}',
      );
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing ProfileBloc - cancelling subscriptions');
    _profileUpdatesSubscription?.cancel();
    return super.close();
  }
}
