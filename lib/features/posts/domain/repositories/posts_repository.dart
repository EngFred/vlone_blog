import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

abstract class PostsRepository {
  // CRUD
  Future<Either<Failure, PostEntity>> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  });
  Future<Either<Failure, Unit>> deletePost(String postId);

  // Retrieval
  Future<Either<Failure, PostEntity>> getPost({
    required String postId,
    required String currentUserId,
  });
  Future<Either<Failure, List<PostEntity>>> getFeed({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  });
  Future<Either<Failure, List<PostEntity>>> getReels({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  });
  Future<Either<Failure, List<PostEntity>>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  });

  // Action
  Future<Either<Failure, Unit>> sharePost({required String postId});

  // NOTE: likePost, favoritePost, getFavorites are REMOVED and moved to
  // LikesRepository and FavoritesRepository.

  // Real-Time Streams
  Stream<Either<Failure, PostEntity>> streamNewPosts();
  Stream<Either<Failure, Map<String, dynamic>>> streamPostUpdates();
  Stream<Either<Failure, String>> streamPostDeletions();
}
