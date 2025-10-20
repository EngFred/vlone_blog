part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class GetProfileDataEvent extends ProfileEvent {
  final String userId;

  const GetProfileDataEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UpdateProfileEvent extends ProfileEvent {
  final String userId;
  final String? username;
  final String? bio;
  final XFile? profileImage;

  const UpdateProfileEvent({
    required this.userId,
    this.username,
    this.bio,
    this.profileImage,
  });

  @override
  List<Object?> get props => [userId, username, bio, profileImage];
}
