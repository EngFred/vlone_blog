import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';

abstract class PostsRepository {
  Future<Either<Failure, PostEntity>> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  });
  Future<Either<Failure, List<PostEntity>>> getFeed({
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, List<PostEntity>>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, Unit>> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  });
  Future<Either<Failure, Unit>> sharePost({required String postId});
  Stream<List<PostEntity>> getFeedStream();
}
