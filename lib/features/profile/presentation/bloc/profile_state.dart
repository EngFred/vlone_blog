part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  @override
  List<Object> get props => [];
}

class ProfileLoading extends ProfileState {
  @override
  List<Object> get props => [];
}

class ProfileDataLoaded extends ProfileState {
  final ProfileEntity profile;
  final String userId;
  // **NEW:** Property to track if the real-time listener is active.
  final bool isRealtimeActive;

  const ProfileDataLoaded({
    required this.profile,
    required this.userId,
    this.isRealtimeActive = false, // Default to false
  });

  // Helper method for easy state updates
  ProfileDataLoaded copyWith({
    ProfileEntity? profile,
    String? userId,
    bool? isRealtimeActive,
  }) {
    return ProfileDataLoaded(
      profile: profile ?? this.profile,
      userId: userId ?? this.userId,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
    );
  }

  @override
  List<Object> get props => [profile, userId, isRealtimeActive];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}
