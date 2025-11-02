import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final RealtimeService realtimeService;

  // Stream subscription for real-time profile updates (per bloc instance)
  StreamSubscription<Map<String, dynamic>>? _profileUpdatesSub;

  ProfileBloc({
    required this.getProfileUseCase,
    // Removed: required this.updateProfileUseCase,
    required this.realtimeService,
  }) : super(ProfileInitial()) {
    on<GetProfileDataEvent>(_onGetProfile);
    // Removed: on<UpdateProfileEvent>(_onUpdateProfile);
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
        emit(ProfileDataLoaded(profile: profile, userId: event.userId));
      },
    );
  }

  Future<void> _onStartProfileRealtime(
    StartProfileRealtimeEvent event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info(
      'ProfileBloc: subscribing to RealtimeService profile updates',
    );

    await _profileUpdatesSub?.cancel();

    _profileUpdatesSub = realtimeService.onProfileUpdate.listen(
      (updateData) {
        try {
          add(_RealtimeProfileUpdatedEvent(updateData));
        } catch (e) {
          AppLogger.error(
            'ProfileBloc: error processing realtime update: $e',
            error: e,
          );
        }
      },
      onError: (err) => AppLogger.error(
        'ProfileBloc: RealtimeService.onProfileUpdate error: $err',
        error: err,
      ),
    );
  }

  Future<void> _onStopProfileRealtime(
    StopProfileRealtimeEvent event,
    Emitter<ProfileState> emit,
  ) async {
    AppLogger.info('ProfileBloc: stopping profile realtime subscription');
    await _profileUpdatesSub?.cancel();
    _profileUpdatesSub = null;
  }

  void _onRealtimeProfileUpdated(
    _RealtimeProfileUpdatedEvent event,
    Emitter<ProfileState> emit,
  ) {
    final currentState = state;
    if (currentState is ProfileDataLoaded) {
      // Create updated profile from data (expecting a map shape)
      try {
        final updateData = event.updateData;
        final updateUserId = updateData['user_id'] as String?; //Extract user_id
        final updatedProfile = ProfileModel.fromMap(
          // Remove 'user_id' if present to parse the rest
          Map.from(updateData)..remove('user_id'),
        ).toEntity();

        // Apply only if matches current profile (prevents overwrite)
        if (updateUserId == currentState.profile.id) {
          emit(
            ProfileDataLoaded(profile: updatedProfile, userId: updateUserId!),
          );
          AppLogger.info(
            'Profile updated in real-time for user: ${updatedProfile.id}',
          );
        } else {
          AppLogger.info(
            'Ignoring real-time profile update for non-matching user: $updateUserId (current: ${currentState.profile.id})',
          );
        }
      } catch (e) {
        AppLogger.error(
          'ProfileBloc: failed to parse realtime profile update: $e',
          error: e,
        );
      }
    }
  }

  @override
  Future<void> close() {
    AppLogger.info('Closing ProfileBloc - cancelling subscriptions');
    _profileUpdatesSub?.cancel();
    return super.close();
  }
}
