import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class PostModel {
  final String id;
  final String userId;
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final String? thumbnailUrl;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;
  final int viewsCount;
  final bool isLiked;
  final bool isFavorited;
  final String? username;
  final String? avatarUrl;

  PostModel({
    required this.id,
    required this.userId,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.thumbnailUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.favoritesCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
    this.viewsCount = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.username,
    this.avatarUrl,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    // 💡 FIX: Determine the source of profile data.
    // Check if it's the flat RPC structure (username at top level)
    final isRpcFlat = map.containsKey('username');

    // Assign the map source: either the entire map (RPC) or the nested 'profiles' sub-map (standard select)
    final profileSource = isRpcFlat
        ? map
        : (map['profiles'] as Map<String, dynamic>?);

    return PostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      mediaType: map['media_type'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      likesCount: map['likes_count'] as int? ?? 0,
      commentsCount: map['comments_count'] as int? ?? 0,
      favoritesCount: map['favorites_count'] as int? ?? 0,
      sharesCount: map['shares_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isPublic: map['is_public'] as bool? ?? true,
      viewsCount: map['views_count'] as int? ?? 0,

      // These fields are returned by the RPC as top-level keys, but are safe to check here
      isLiked: map['is_liked'] as bool? ?? false,
      isFavorited: map['is_favorited'] as bool? ?? false,

      // Extract profile data from the determined source
      username: profileSource?['username'] as String?,
      avatarUrl: profileSource?['profile_image_url'] as String?,
    );
  }

  PostEntity toEntity() {
    return PostEntity(
      id: id,
      userId: userId,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
      likesCount: likesCount,
      commentsCount: commentsCount,
      favoritesCount: favoritesCount,
      sharesCount: sharesCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPublic: isPublic,
      viewsCount: viewsCount,
      isLiked: isLiked,
      isFavorited: isFavorited,
      username: username,
      avatarUrl: avatarUrl,
    );
  }
}
