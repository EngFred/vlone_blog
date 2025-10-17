import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int totalLikes;

  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    this.bio,
    this.profileImageUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.totalLikes = 0,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    username,
    bio,
    profileImageUrl,
    followersCount,
    followingCount,
    postsCount,
    totalLikes,
  ];
}
