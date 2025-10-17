import 'package:equatable/equatable.dart';

class FavoriteEntity extends Equatable {
  final String id;
  final String postId;
  final String userId;

  const FavoriteEntity({
    required this.id,
    required this.postId,
    required this.userId,
  });

  @override
  List<Object> get props => [id, postId, userId];
}
