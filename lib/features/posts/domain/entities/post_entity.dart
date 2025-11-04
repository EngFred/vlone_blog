import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class PostEntity extends Equatable {
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

  const PostEntity({
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
  });

  PostEntity copyWith({
    String? id,
    String? userId,
    String? content,
    String? mediaUrl,
    String? mediaType,
    String? thumbnailUrl,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    int? sharesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    int? viewsCount,
    bool? isLiked,
    bool? isFavorited,
    String? username,
    String? avatarUrl,
    int? mediaWidth,
    int? mediaHeight,
  }) {
    return PostEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      viewsCount: viewsCount ?? this.viewsCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
    );
  }

  String get formattedCreatedAt {
    return DateFormat('MMM d, yyyy HH:mm').format(createdAt);
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    content,
    mediaUrl,
    mediaType,
    thumbnailUrl,
    likesCount,
    commentsCount,
    favoritesCount,
    sharesCount,
    createdAt,
    updatedAt,
    isPublic,
    viewsCount,
    isLiked,
    isFavorited,
    username,
    avatarUrl,
    mediaWidth,
    mediaHeight,
    // REMOVED: uploadStatus,
  ];
}
