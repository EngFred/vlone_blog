import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/update_profile_usecase.dart';

part 'edit_profile_event.dart';
part 'edit_profile_state.dart';

// A sensible duration for debouncing text field validation
const _debounceDuration = Duration(milliseconds: 300);

// We make it generic over <E extends EditProfileEvent>
EventTransformer<E> debouncedTransformer<E extends EditProfileEvent>(
  Duration duration,
) {
  return (events, mapper) {
    // Use debounceTime from rxdart and switchMap (restartable logic)
    // to handle only the latest debounced event.
    return events.debounceTime(duration).switchMap(mapper);
  };
}

class EditProfileBloc extends Bloc<EditProfileEvent, EditProfileState> {
  // Removed: final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;

  EditProfileBloc({
    // Removed: required this.getProfileUseCase,
    required this.updateProfileUseCase,
  }) : super(EditProfileInitial()) {
    // Register all event handlers here instead of using mapEventToState

    // 'restartable' cancels previous API calls if a new one comes in
    on<LoadInitialProfileEvent>(
      _onLoadInitialProfile,
      transformer: restartable(),
    );

    // Apply the debounced transformer with the correct type argument
    on<ChangeUsernameEvent>(
      _onChangeUsername,
      transformer: debouncedTransformer(_debounceDuration),
    );
    on<ChangeBioEvent>(
      _onChangeBio,
      transformer: debouncedTransformer(_debounceDuration),
    );

    // 'sequential' (the default) is fine here
    on<SelectImageEvent>(_onSelectImage);

    // 'droppable' prevents spam-clicking the submit button
    on<SubmitChangesEvent>(_onSubmitChanges, transformer: droppable());
  }

  // Updated handler to take the profile directly from the event
  Future<void> _onLoadInitialProfile(
    LoadInitialProfileEvent event,
    Emitter<EditProfileState> emit,
  ) async {
    // No need to emit Loading state as data is synchronous
    final profile = event.profile;

    // Immediately emit the editing state with the authenticated user's data
    emit(
      EditProfileEditing(
        userId: profile.id, // Use profile.id instead of event.userId
        initialUsername: profile.username,
        initialBio: profile.bio ?? '',
        initialImageUrl: profile.profileImageUrl,
        currentUsername: profile.username,
        currentBio: profile.bio ?? '',
        selectedImage: null,
        isSubmitting: false,
        usernameError: null,
        bioError: null,
        generalError: null,
      ),
    );
  }

  void _onChangeUsername(
    ChangeUsernameEvent event,
    Emitter<EditProfileState> emit,
  ) {
    // 'state' is the current state of the BLoC
    if (state is EditProfileEditing) {
      final currentState = state as EditProfileEditing;
      final trimmed = event.username.trim();
      String? error;
      if (trimmed.isEmpty) {
        error = 'Username cannot be empty';
      } else if (trimmed.length < 3) {
        error = 'Username too short';
      } else if (trimmed.length > 30) {
        error = 'Username too long';
      }
      // 'emit' a new state instead of 'yield'
      emit(
        currentState.copyWith(
          currentUsername: event.username,
          usernameError: error,
        ),
      );
    }
  }

  void _onChangeBio(ChangeBioEvent event, Emitter<EditProfileState> emit) {
    if (state is EditProfileEditing) {
      final currentState = state as EditProfileEditing;
      final trimmed = event.bio.trim();
      String? error;
      if (trimmed.length > 100) {
        error = 'Bio too long (max 100 characters)';
      }
      emit(currentState.copyWith(currentBio: event.bio, bioError: error));
    }
  }

  void _onSelectImage(SelectImageEvent event, Emitter<EditProfileState> emit) {
    if (state is EditProfileEditing) {
      final currentState = state as EditProfileEditing;
      emit(currentState.copyWith(selectedImage: event.image));
    }
  }

  Future<void> _onSubmitChanges(
    SubmitChangesEvent event,
    Emitter<EditProfileState> emit,
  ) async {
    if (state is EditProfileEditing) {
      final currentState = state as EditProfileEditing;

      // Guard against submission if there are errors or already submitting
      if (currentState.usernameError != null ||
          currentState.bioError != null ||
          currentState.isSubmitting) {
        return;
      }

      final newUsername = currentState.currentUsername.trim();
      final newBio = currentState.currentBio.trim().isEmpty
          ? null
          : currentState.currentBio.trim();
      final usernameChanged = newUsername != currentState.initialUsername;
      final bioChanged = newBio != currentState.initialBio;
      final hasImage = currentState.selectedImage != null;

      if (!usernameChanged && !bioChanged && !hasImage) {
        emit(currentState.copyWith(generalError: 'No changes detected.'));
        // We need to clear the error after a moment
        await Future.delayed(const Duration(seconds: 2));
        if (state ==
            currentState.copyWith(generalError: 'No changes detected.')) {
          emit(currentState.copyWith(generalError: null));
        }
        return;
      }

      emit(currentState.copyWith(isSubmitting: true, generalError: null));

      final result = await updateProfileUseCase(
        UpdateProfileParams(
          userId: currentState.userId,
          username: usernameChanged ? newUsername : null,
          bio: bioChanged ? newBio : null,
          profileImage: hasImage ? currentState.selectedImage : null,
        ),
      );

      result.fold(
        (failure) {
          final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('UpdateProfile failed: $friendlyMessage');
          emit(
            currentState.copyWith(
              isSubmitting: false,
              generalError: friendlyMessage,
            ),
          );
        },
        (profile) {
          AppLogger.info('Profile updated successfully: ${profile.id}');
          emit(EditProfileSuccess(updatedProfile: profile));
        },
      );
    }
  }
}
