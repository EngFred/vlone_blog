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
  final bool isRealtimeActive;
  // ADDED: Optional completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const ProfileDataLoaded({
    required this.profile,
    required this.userId,
    this.isRealtimeActive = false, // Default to false
    this.refreshCompleter,
  });

  // Helper method for easy state updates
  ProfileDataLoaded copyWith({
    ProfileEntity? profile,
    String? userId,
    bool? isRealtimeActive,
    Completer<void>? refreshCompleter,
  }) {
    return ProfileDataLoaded(
      profile: profile ?? this.profile,
      userId: userId ?? this.userId,
      isRealtimeActive: isRealtimeActive ?? this.isRealtimeActive,
      refreshCompleter: refreshCompleter,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    userId,
    isRealtimeActive,
    refreshCompleter,
  ];
}

class ProfileError extends ProfileState {
  final String message;
  // ADDED: Optional completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const ProfileError(this.message, {this.refreshCompleter});

  @override
  List<Object?> get props => [message, refreshCompleter];
}
