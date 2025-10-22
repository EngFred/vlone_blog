import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class UserListModel {
  final String id;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final bool isFollowing;

  UserListModel({
    required this.id,
    required this.username,
    this.bio,
    this.profileImageUrl,
    required this.isFollowing,
  });

  factory UserListModel.fromMap(Map<String, dynamic> map) {
    return UserListModel(
      id: map['id'] as String,
      username: map['username'] as String,
      bio: map['bio'] as String?,
      profileImageUrl: map['profile_image_url'] as String?,
      isFollowing: map['is_following'] as bool? ?? false,
    );
  }

  UserListEntity toEntity() {
    return UserListEntity(
      id: id,
      username: username,
      bio: bio,
      profileImageUrl: profileImageUrl,
      isFollowing: isFollowing,
    );
  }
}
