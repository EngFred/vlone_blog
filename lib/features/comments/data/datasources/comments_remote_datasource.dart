import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
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

      return CommentModel.fromMap(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final response = await client
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return response.map((map) => CommentModel.fromMap(map)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .map((list) => list.map((map) => CommentModel.fromMap(map)).toList());
  }
}
