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

  const ProfileDataLoaded({required this.profile, required this.userId});

  @override
  List<Object> get props => [profile, userId];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}
