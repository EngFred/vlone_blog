import 'package:vlone_blog_app/features/followers/domain/entities/follower_entity.dart';

class FollowerModel {
  final String id;
  final String followerId;
  final String followingId;

  FollowerModel({
    required this.id,
    required this.followerId,
    required this.followingId,
  });

  factory FollowerModel.fromMap(Map<String, dynamic> map) {
    return FollowerModel(
      id: map['id'] as String,
      followerId: map['follower_id'] as String,
      followingId: map['following_id'] as String,
    );
  }

  FollowerEntity toEntity() {
    return FollowerEntity(
      id: id,
      followerId: followerId,
      followingId: followingId,
    );
  }
}
