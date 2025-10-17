import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class ProfileModel {
  final String id;
  final String email;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int totalLikes;

  ProfileModel({
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

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
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

  ProfileEntity toEntity() {
    return ProfileEntity(
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
