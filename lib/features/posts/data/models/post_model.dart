import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

class PostModel {
  final String id;
  final String userId;
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;
  final int viewsCount;

  PostModel({
    required this.id,
    required this.userId,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.favoritesCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
    this.viewsCount = 0,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      mediaType: map['media_type'] as String?,
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
    );
  }

  PostEntity toEntity() {
    return PostEntity(
      id: id,
      userId: userId,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      likesCount: likesCount,
      commentsCount: commentsCount,
      favoritesCount: favoritesCount,
      sharesCount: sharesCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPublic: isPublic,
      viewsCount: viewsCount,
    );
  }
}
