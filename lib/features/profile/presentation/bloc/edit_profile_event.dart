part of 'edit_profile_bloc.dart';

abstract class EditProfileEvent extends Equatable {
  const EditProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadInitialProfileEvent extends EditProfileEvent {
  final ProfileEntity profile;

  const LoadInitialProfileEvent(this.profile);

  @override
  List<Object> get props => [profile];
}

class ChangeUsernameEvent extends EditProfileEvent {
  final String username;

  const ChangeUsernameEvent(this.username);

  @override
  List<Object?> get props => [username];
}

class ChangeBioEvent extends EditProfileEvent {
  final String bio;

  const ChangeBioEvent(this.bio);

  @override
  List<Object?> get props => [bio];
}

class SelectImageEvent extends EditProfileEvent {
  final XFile? image;

  const SelectImageEvent(this.image);

  @override
  List<Object?> get props => [image];
}

class SubmitChangesEvent extends EditProfileEvent {}
