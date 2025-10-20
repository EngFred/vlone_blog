import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/data/datasources/posts_remote_datasource.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/interaction_states.dart';
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
      AppLogger.error(
        'ServerException in createPost repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getFeed() async {
    try {
      final postModels = await remoteDataSource.getFeed();
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in getFeed repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PostEntity>>> getUserPosts(String userId) async {
    try {
      final postModels = await remoteDataSource.getUserPosts(userId: userId);
      return Right(postModels.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in getUserPosts repo: ${e.message}',
        error: e,
      );
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
      AppLogger.error(
        'ServerException in likePost repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sharePost({required String postId}) async {
    try {
      await remoteDataSource.sharePost(postId: postId);
      return const Right(unit);
    } on ServerException catch (e) {
      AppLogger.error(
        'ServerException in sharePost repo: ${e.message}',
        error: e,
      );
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, InteractionStates>> getPostInteractions({
    required String userId,
    required List<String> postIds,
  }) async {
    try {
      final map = await remoteDataSource.getInteractions(
        userId: userId,
        postIds: postIds,
      );
      final liked = (map['liked'] ?? <String>[])
          .map((e) => e.toString())
          .toSet();
      final favorited = (map['favorited'] ?? <String>[])
          .map((e) => e.toString())
          .toSet();
      final states = InteractionStates(
        likedPostIds: liked,
        favoritedPostIds: favorited,
      );
      return right(states);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.error('PostsRepositoryImpl.getPostInteractions error: $e');
      return left(ServerFailure(e.toString()));
    }
  }
}
