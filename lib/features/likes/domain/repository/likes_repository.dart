import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';

abstract class LikesRepository {
  /// Toggle a like status on a post.
  Future<Either<Failure, Unit>> likePost({
    required String postId,
    required String userId,
    required bool isLiked, // true to like, false to unlike
  });

  /// Stream of real-time like/unlike events for updating UI counts.
  Stream<Either<Failure, Map<String, dynamic>>> streamLikes();
}
