import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/comments/data/models/comment_model.dart';

class CommentsRemoteDataSource {
  final SupabaseClient client;

  CommentsRemoteDataSource(this.client);

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
  }) async {
    AppLogger.info(
      'Adding comment for post: $postId by user: $userId, parent: $parentCommentId',
    );
    try {
      final commentData = {
        'post_id': postId,
        'user_id': userId,
        'text': text,
        'parent_comment_id': parentCommentId,
      };
      final response = await client
          .from('comments')
          .insert(commentData)
          .select()
          .single();
      AppLogger.info('Comment added successfully for post: $postId');
      return CommentModel.fromMap(response);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to add comment for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<CommentModel>> getComments(String postId) async {
    AppLogger.info('Fetching comments for post: $postId');
    try {
      final response = await client
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      final comments = response
          .map((map) => CommentModel.fromMap(map))
          .toList();
      AppLogger.info('Fetched ${comments.length} comments for post: $postId');
      return comments;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch comments for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Stream<List<CommentModel>> getCommentsStream(String postId) {
    AppLogger.info('Subscribing to comments stream for post: $postId');
    try {
      final stream = client
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .map((list) {
            final comments = list
                .map((map) => CommentModel.fromMap(map))
                .toList();
            AppLogger.info(
              'Received ${comments.length} comments in stream for post: $postId',
            );
            return comments;
          });
      return stream;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to subscribe to comments stream for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }
}
