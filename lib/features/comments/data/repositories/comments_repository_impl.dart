import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/domain/errors/failure.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

class CommentsRepositoryImpl implements CommentsRepository {
  final CommentsRemoteDataSource remoteDataSource;
  CommentsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, CommentEntity>> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      final commentModel = await remoteDataSource.addComment(
        postId: postId,
        userId: userId,
        text: text,
        parentCommentId: parentCommentId,
      );
      return Right(commentModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getInitialComments(
    String postId, {
    int pageSize = 20,
  }) async {
    try {
      final commentModels = await remoteDataSource.getComments(
        postId,
        pageSize: pageSize,
      );
      final entities = commentModels.map((model) => model.toEntity()).toList();
      final tree = _buildCommentTree(entities);
      return Right(tree);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> loadMoreComments(
    String postId, {
    required DateTime lastCreatedAt,
    required String lastId,
    int pageSize = 20,
  }) async {
    try {
      final moreModels = await remoteDataSource.getComments(
        postId,
        pageSize: pageSize,
        lastCreatedAt: lastCreatedAt,
        lastId: lastId,
      );
      // CHANGE: Append to stream cache (for realtime consistency), but *return* new models for explicit pagination in Bloc.
      remoteDataSource.appendMoreComments(postId, moreModels);
      final newEntities = moreModels.map((model) => model.toEntity()).toList();
      final newTree = _buildCommentTree(
        newEntities,
      ); // Build subtree for new batch
      return Right(newTree);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<CommentEntity>> getCommentsStream(String postId) {
    return remoteDataSource.getCommentsStream(postId).map((models) {
      final entities = models.map((m) => m.toEntity()).toList();
      return _buildCommentTree(entities);
    });
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> streamCommentEvents() {
    try {
      return remoteDataSource
          .streamCommentEvents()
          .map(
            (commentEvent) =>
                Right<Failure, Map<String, dynamic>>(commentEvent),
          )
          .handleError((error) {
            AppLogger.error(
              'Error in streamCommentEvents repo: $error',
              error: error,
            );
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(error.toString()),
            );
          });
    } catch (e) {
      AppLogger.error('Exception setting up streamCommentEvents: $e', error: e);
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  /// Builds nested tree using server-provided replies_count
  static List<CommentEntity> _buildCommentTree(List<CommentEntity> comments) {
    if (comments.isEmpty) return [];

    final childrenMap = <String, List<CommentEntity>>{};
    final roots = <CommentEntity>[];

    for (final comment in comments) {
      final parentId = comment.parentCommentId;
      if (parentId == null) {
        roots.add(comment);
      } else {
        childrenMap.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    // Sort roots newest first (server already did this, but safe)
    roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort children newest first
    for (final children in childrenMap.values) {
      children.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    CommentEntity _buildNode(CommentEntity node) {
      final children = childrenMap[node.id] ?? [];
      final builtChildren = children.map((child) {
        final childWithParent = child.copyWith(parentUsername: node.username);
        return _buildNode(childWithParent);
      }).toList();

      return node.copyWith(replies: builtChildren);
    }

    return roots.map(_buildNode).toList();
  }
}
