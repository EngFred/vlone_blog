import 'package:vlone_blog_app/features/auth/domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int totalLikes;

  UserModel({
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

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      username: map['username'] as String,
      bio: map['bio'] as String?,
      profileImageUrl: map['profile_image_url'] as String?,
      followersCount: map['followers_count'] as int? ?? 0,
      followingCount: map['following_count'] as int? ?? 0,
      postsCount: map['posts_count'] as int? ?? 0,
      totalLikes: map['total_likes'] as int? ?? 0,
    );
  }

  // Mapper to entity (can be extension or separate class for scalability)
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      username: username,
      bio: bio,
      profileImageUrl: profileImageUrl,
      followersCount: followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
      totalLikes: totalLikes,
    );
  }
}
