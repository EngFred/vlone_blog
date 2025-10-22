import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/interaction_states.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

abstract class PostsRepository {
  Future<Either<Failure, PostEntity>> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  });

  Future<Either<Failure, List<PostEntity>>> getFeed();

  Future<Either<Failure, List<PostEntity>>> getReels();

  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId);

  Future<Either<Failure, List<PostEntity>>> getFavorites({
    required String userId,
  });

  Future<Either<Failure, Unit>> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  });

  Future<Either<Failure, Unit>> favoritePost({
    required String postId,
    required String userId,
    required bool isFavorited,
  });

  Future<Either<Failure, Unit>> sharePost({required String postId});

  Future<Either<Failure, InteractionStates>> getPostInteractions({
    required String userId,
    required List<String> postIds,
  });

  Future<Either<Failure, PostEntity>> getPost(String postId);

  // ==================== REAL-TIME STREAMS ====================

  /// Stream of newly created posts
  Stream<Either<Failure, PostEntity>> streamNewPosts();

  /// Stream of post updates (likes, comments, favorites counts)
  Stream<Either<Failure, Map<String, dynamic>>> streamPostUpdates();

  /// Stream of like events
  Stream<Either<Failure, Map<String, dynamic>>> streamLikes();

  /// Stream of comment events
  Stream<Either<Failure, Map<String, dynamic>>> streamComments();

  /// Stream of favorite events
  Stream<Either<Failure, Map<String, dynamic>>> streamFavorites();
}
