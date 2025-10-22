import 'package:equatable/equatable.dart';

class UserListEntity extends Equatable {
  final String id;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final bool isFollowing;

  const UserListEntity({
    required this.id,
    required this.username,
    this.bio,
    this.profileImageUrl,
    required this.isFollowing,
  });

  UserListEntity copyWith({
    String? id,
    String? username,
    String? bio,
    String? profileImageUrl,
    bool? isFollowing,
  }) {
    return UserListEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [id, username, bio, profileImageUrl, isFollowing];
}
