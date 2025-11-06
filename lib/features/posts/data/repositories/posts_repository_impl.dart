import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/features/posts/data/datasources/posts_remote_datasource.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/media_file_type.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class PostsRepositoryImpl implements PostsRepository {
  final PostsRemoteDataSource remoteDataSource;

  PostsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, Unit>> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    MediaType? mediaType,
  }) async {
    try {
      final String? mediaTypeString = mediaType?.name;

      await remoteDataSource.createPost(
        userId: userId,
        content: content,
        mediaFile: mediaFile,
        mediaType: mediaTypeString,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFeed({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final postModels = await remoteDataSource.getFeed(
        currentUserId: currentUserId,
        pageSize: pageSize,
        lastCreatedAt: lastCreatedAt,
        lastId: lastId,
      );
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getReels({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final postModels = await remoteDataSource.getReels(
        currentUserId: currentUserId,
        pageSize: pageSize,
        lastCreatedAt: lastCreatedAt,
        lastId: lastId,
      );
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts({
    required String profileUserId,
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final postModels = await remoteDataSource.getUserPosts(
        profileUserId: profileUserId,
        currentUserId: currentUserId,
        pageSize: pageSize,
        lastCreatedAt: lastCreatedAt,
        lastId: lastId,
      );
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sharePost({required String postId}) async {
    try {
      await remoteDataSource.sharePost(postId: postId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> getPost({
    required String postId,
    required String currentUserId,
  }) async {
    try {
      final postModel = await remoteDataSource.getPost(
        postId: postId,
        currentUserId: currentUserId,
      );
      return Right(postModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePost(String postId) async {
    try {
      await remoteDataSource.deletePost(postId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  // ==================== REAL-TIME STREAMS ====================

  @override
  Stream<Either<Failure, PostEntity>> streamNewPosts() {
    try {
      return remoteDataSource
          .streamNewPosts()
          .map((postModel) => Right<Failure, PostEntity>(postModel.toEntity()))
          .handleError((error) {
            return Left<Failure, PostEntity>(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamPostUpdates() {
    try {
      return remoteDataSource
          .streamPostUpdates()
          .map((update) => Right<Failure, Map<String, dynamic>>(update))
          .handleError((error) {
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, String>> streamPostDeletions() {
    try {
      return remoteDataSource
          .streamPostDeletions()
          .map((postId) => Right<Failure, String>(postId))
          .handleError((error) {
            return Left<Failure, String>(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
