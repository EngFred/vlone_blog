import 'package:vlone_blog_app/features/favorites/domain/entities/favorite_entity.dart';

class FavoriteModel {
  final String id;
  final String postId;
  final String userId;

  FavoriteModel({required this.id, required this.postId, required this.userId});

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
    );
  }

  FavoriteEntity toEntity() {
    return FavoriteEntity(id: id, postId: postId, userId: userId);
  }
}
