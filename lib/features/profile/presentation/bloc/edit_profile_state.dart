part of 'edit_profile_bloc.dart';

abstract class EditProfileState extends Equatable {
  const EditProfileState();

  @override
  List<Object?> get props => [];
}

class EditProfileInitial extends EditProfileState {}

class EditProfileLoading extends EditProfileState {}

class EditProfileEditing extends EditProfileState {
  final String userId;
  final String initialUsername;
  final String initialBio;
  final String? initialImageUrl;
  final String currentUsername;
  final String currentBio;
  final XFile? selectedImage;
  final bool isSubmitting;
  final String? usernameError;
  final String? bioError;
  final String? generalError;

  const EditProfileEditing({
    required this.userId,
    required this.initialUsername,
    required this.initialBio,
    this.initialImageUrl,
    required this.currentUsername,
    required this.currentBio,
    this.selectedImage,
    required this.isSubmitting,
    this.usernameError,
    this.bioError,
    this.generalError,
  });

  EditProfileEditing copyWith({
    String? userId,
    String? initialUsername,
    String? initialBio,
    String? initialImageUrl,
    String? currentUsername,
    String? currentBio,
    XFile? selectedImage,
    bool? isSubmitting,
    Object? usernameError = const _Optional(),
    Object? bioError = const _Optional(),
    Object? generalError = const _Optional(),
  }) {
    return EditProfileEditing(
      userId: userId ?? this.userId,
      initialUsername: initialUsername ?? this.initialUsername,
      initialBio: initialBio ?? this.initialBio,
      initialImageUrl: initialImageUrl ?? this.initialImageUrl,
      currentUsername: currentUsername ?? this.currentUsername,
      currentBio: currentBio ?? this.currentBio,
      selectedImage: selectedImage ?? this.selectedImage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      usernameError: usernameError is _Optional
          ? this.usernameError
          : usernameError as String?,
      bioError: bioError is _Optional ? this.bioError : bioError as String?,
      generalError: generalError is _Optional
          ? this.generalError
          : generalError as String?,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    initialUsername,
    initialBio,
    initialImageUrl,
    currentUsername,
    currentBio,
    selectedImage,
    isSubmitting,
    usernameError,
    bioError,
    generalError,
  ];
}

class _Optional {
  const _Optional();
}

class EditProfileSuccess extends EditProfileState {
  final ProfileEntity updatedProfile;

  const EditProfileSuccess({required this.updatedProfile});

  @override
  List<Object?> get props => [updatedProfile];
}

class EditProfileError extends EditProfileState {
  final String message;

  const EditProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
