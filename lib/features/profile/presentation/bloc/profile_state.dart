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

// Our main success state. It holds the loaded profile and tracks the status of the posts separately.
class ProfileDataLoaded extends ProfileState {
  final ProfileEntity profile;
  final List<PostEntity> posts;
  final bool arePostsLoading;
  final String? postsError;

  const ProfileDataLoaded({
    required this.profile,
    this.posts = const [],
    this.arePostsLoading = false,
    this.postsError,
  });

  // A handy method to create a new state instance with updated values.
  ProfileDataLoaded copyWith({
    ProfileEntity? profile,
    List<PostEntity>? posts,
    bool? arePostsLoading,
    String? postsError,
  }) {
    return ProfileDataLoaded(
      profile: profile ?? this.profile,
      posts: posts ?? this.posts,
      arePostsLoading: arePostsLoading ?? this.arePostsLoading,
      postsError: postsError, // Allow setting error to null
    );
  }

  @override
  List<Object?> get props => [profile, posts, arePostsLoading, postsError];
}
