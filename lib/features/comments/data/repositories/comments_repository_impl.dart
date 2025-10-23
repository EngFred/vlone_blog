import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
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
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId,
  ) async {
    try {
      final commentModels = await remoteDataSource.getComments(postId);
      final entities = commentModels.map((model) => model.toEntity()).toList();
      final tree = _buildCommentTree(entities);
      return Right(tree);
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

  /// Builds a nested comment tree immutably and bottom-up.
  static List<CommentEntity> _buildCommentTree(List<CommentEntity> comments) {
    if (comments.isEmpty) return [];

    final childrenMap = <String, List<CommentEntity>>{};
    final roots = <CommentEntity>[];

    // Step 1: Collect roots and populate children map
    for (final comment in comments) {
      final parentId = comment.parentCommentId;
      if (parentId == null) {
        roots.add(comment);
      } else {
        childrenMap.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    // Step 2: Sort roots and each children list by createdAt ascending
    roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final children in childrenMap.values) {
      children.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // Step 3: Recursively build the tree bottom-up
    CommentEntity _buildNode(CommentEntity node) {
      final children = childrenMap[node.id] ?? [];
      final builtChildren = children.map((child) {
        // CRITICAL FIX: node is the parent, so we use node.username.
        final childWithParentContext = child.copyWith(
          parentUsername: node.username,
        );
        return _buildNode(childWithParentContext);
      }).toList();

      return node.copyWith(replies: builtChildren);
    }

    // Step 4: Build final roots
    final builtRoots = roots.map(_buildNode).toList();

    AppLogger.info(
      'Built comment tree with ${builtRoots.length} roots and total ${comments.length} comments',
    );

    return builtRoots;
  }
}
