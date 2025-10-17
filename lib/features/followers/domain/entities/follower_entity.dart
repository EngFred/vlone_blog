import 'package:equatable/equatable.dart';

class FollowerEntity extends Equatable {
  final String id;
  final String followerId;
  final String followingId;

  const FollowerEntity({
    required this.id,
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object> get props => [id, followerId, followingId];
}
