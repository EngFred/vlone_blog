import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/features/posts/data/datasources/posts_remote_datasource.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class PostsRepositoryImpl implements PostsRepository {
  final PostsRemoteDataSource remoteDataSource;

  PostsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, PostEntity>> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    try {
      final postModel = await remoteDataSource.createPost(
        userId: userId,
        content: content,
        mediaFile: mediaFile,
        mediaType: mediaType,
      );
      return Right(postModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFeed({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final postModels = await remoteDataSource.getFeed(
        page: page,
        limit: limit,
      );
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await remoteDataSource.client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      final postModels = response.map((map) => PostModel.fromMap(map)).toList();
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      await remoteDataSource.likePost(
        postId: postId,
        userId: userId,
        isLiked: isLiked,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sharePost({required String postId}) async {
    try {
      final shareUrl = 'Check this post: https://yourapp.com/post/$postId';
      await remoteDataSource.sharePost(postId: postId, shareUrl: shareUrl);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<PostEntity>> getFeedStream() {
    return remoteDataSource.getFeedStream().map(
      (models) => models.map((m) => m.toEntity()).toList(),
    );
  }
}
