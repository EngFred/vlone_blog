import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

abstract class FavoritesRepository {
  /// Toggle a favorite status on a post.
  Future<Either<Failure, Unit>> favoritePost({
    required String postId,
    required String userId,
    required bool isFavorited, // true to favorite, false to unfavorite
  });

  /// Fetch all posts favorited by the user.
  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
  });

  /// Stream of real-time favorite/unfavorite events for updating UI counts.
  Stream<Either<Failure, Map<String, dynamic>>> streamFavorites();
}
