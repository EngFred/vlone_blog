part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;

  ProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class UserPostsLoaded extends ProfileState {
  final List<PostEntity> posts;

  UserPostsLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class ProfileError extends ProfileState {
  final String message;

  ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
