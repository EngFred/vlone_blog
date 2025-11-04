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

  final int? mediaWidth;
  final int? mediaHeight;

  // REMOVED: final String uploadStatus;

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
    this.mediaWidth,
    this.mediaHeight,
    // REMOVED: this.uploadStatus = 'none',
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? profileSource;
    if (map.containsKey('username')) {
      profileSource = map;
    } else {
      final p = map['profiles'];
      if (p is Map<String, dynamic>) profileSource = p;
    }

    int safeInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    // Helper for null-safe integer parsing (returns null if non-existent or invalid)
    int? safeNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return PostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      mediaType: map['media_type'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      likesCount: safeInt(map['likes_count']),
      commentsCount: safeInt(map['comments_count']),
      favoritesCount: safeInt(map['favorites_count']),
      sharesCount: safeInt(map['shares_count']),
      createdAt: parseDate(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? parseDate(map['updated_at'])
          : null,
      isPublic: map['is_public'] as bool? ?? true,
      viewsCount: safeInt(map['views_count']),
      isLiked: map['is_liked'] as bool? ?? false,
      isFavorited: map['is_favorited'] as bool? ?? false,
      username: profileSource?['username'] as String?,
      avatarUrl: profileSource?['profile_image_url'] as String?,
      mediaWidth: safeNullableInt(map['media_width']),
      mediaHeight: safeNullableInt(map['media_height']),
      // REMOVED: uploadStatus: map['upload_status'] as String? ?? 'none',
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
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      // REMOVED: uploadStatus: uploadStatus,
    );
  }
}
