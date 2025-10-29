import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class UserListModel {
  final String id;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final bool isFollowing;
  final DateTime createdAt;

  UserListModel({
    required this.id,
    required this.username,
    this.bio,
    this.profileImageUrl,
    required this.isFollowing,
    required this.createdAt,
  });

  factory UserListModel.fromMap(Map<String, dynamic> map) {
    // Defensive parsing for 'created_at' in case the RPC doesn't return it (though it should now)
    final createdAtString = map['created_at'] as String?;

    final parsedCreatedAt =
        createdAtString != null && createdAtString.isNotEmpty
        ? DateTime.parse(createdAtString)
        : DateTime(2000); // Use a safe default for non-null required field

    return UserListModel(
      id: map['id'] as String,
      username: map['username'] as String,
      bio: map['bio'] as String?,
      profileImageUrl: map['profile_image_url'] as String?,
      isFollowing: map['is_following'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  UserListEntity toEntity() {
    return UserListEntity(
      id: id,
      username: username,
      bio: bio,
      profileImageUrl: profileImageUrl,
      isFollowing: isFollowing,
      createdAt: createdAt,
    );
  }
}
