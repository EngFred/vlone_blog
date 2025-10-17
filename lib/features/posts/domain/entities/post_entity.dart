import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/utils/extensions.dart';

class PostEntity extends Equatable {
  final String id;
  final String userId;
  final String? content;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'video', 'none'
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;
  final int viewsCount;

  const PostEntity({
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

  String get formattedCreatedAt => createdAt.formattedDateTime;

  @override
  List<Object?> get props => [
    id,
    userId,
    content,
    mediaUrl,
    mediaType,
    likesCount,
    commentsCount,
    favoritesCount,
    sharesCount,
    createdAt,
    updatedAt,
    isPublic,
    viewsCount,
  ];
}
