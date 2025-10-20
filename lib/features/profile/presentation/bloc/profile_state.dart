part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

// This state will only be used for the initial loading of the profile header.
class ProfileLoading extends ProfileState {}

// This state indicates the Profile Header failed to load. It's a critical error.
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

// Our main success state. It holds only the loaded profile.
class ProfileDataLoaded extends ProfileState {
  final ProfileEntity profile;
  const ProfileDataLoaded({required this.profile});

  ProfileDataLoaded copyWith({ProfileEntity? profile}) {
    return ProfileDataLoaded(profile: profile ?? this.profile);
  }

  @override
  List<Object?> get props => [profile];
}
