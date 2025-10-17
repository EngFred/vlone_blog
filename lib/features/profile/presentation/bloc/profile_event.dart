part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetProfileEvent extends ProfileEvent {
  final String userId;

  GetProfileEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UpdateProfileEvent extends ProfileEvent {
  final String userId;
  final String? bio;
  final XFile? profileImage;

  UpdateProfileEvent({required this.userId, this.bio, this.profileImage});

  @override
  List<Object?> get props => [userId, bio, profileImage];
}

class GetUserPostsEvent extends ProfileEvent {
  final String userId;
  final int page;
  final int limit;

  GetUserPostsEvent({required this.userId, this.page = 1, this.limit = 20});

  @override
  List<Object?> get props => [userId, page, limit];
}
