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
      followersCount: (map['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (map['following_count'] as num?)?.toInt() ?? 0,
      postsCount: (map['posts_count'] as num?)?.toInt() ?? 0,
      totalLikes: (map['total_likes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'bio': bio,
      'profile_image_url': profileImageUrl,
      'followers_count': followersCount,
      'following_count': followingCount,
      'posts_count': postsCount,
      'total_likes': totalLikes,
    };
  }

  /// JSON alias
  Map<String, dynamic> toJson() => toMap();

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

  ProfileModel copyWith({
    String? id,
    String? email,
    String? username,
    String? bio,
    String? profileImageUrl,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? totalLikes,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      totalLikes: totalLikes ?? this.totalLikes,
    );
  }
}
