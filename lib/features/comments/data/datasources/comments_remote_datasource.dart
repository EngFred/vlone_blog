import 'dart:async';

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

  // Use view for initial load (unchanged)
  Future<List<CommentModel>> getComments(String postId) async {
    AppLogger.info('Fetching initial comments for post: $postId');
    try {
      final response = await client
          .from('comments_view')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = (response as List)
          .map((map) => CommentModel.fromMap(map as Map<String, dynamic>))
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

  /// Subscribes to changes on the `comments` table filtered by post_id.
  /// On any change, re-fetches the full `comments_view` for the post and yields that list.
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    AppLogger.info('Subscribing to comments table stream for post: $postId');

    // Create a controller so we can close the subscription cleanly.
    final controller = StreamController<List<CommentModel>>();

    // Listen for realtime changes on the comments table filtered by post_id.
    // Supabase stream returns Stream<List<Map<String, dynamic>>> per docs.
    try {
      final realtimeStream = client
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('post_id', postId);

      // When the realtime stream emits (any insert/update/delete), re-query the view.
      final subscription = realtimeStream.listen(
        (_) async {
          try {
            AppLogger.info(
              'Realtime event for post $postId received — refetching view',
            );

            final response = await client
                .from('comments_view')
                .select()
                .eq('post_id', postId)
                .order('created_at', ascending: true);

            final comments = (response as List)
                .map((map) => CommentModel.fromMap(map as Map<String, dynamic>))
                .toList();

            AppLogger.info(
              'Realtime refetch produced ${comments.length} comments for post: $postId',
            );

            if (!controller.isClosed && controller.hasListener) {
              controller.add(comments);
            }
          } catch (e, stackTrace) {
            AppLogger.error(
              'Failed to refetch comments_view after realtime event for post: $postId, error: $e',
              error: e,
              stackTrace: stackTrace,
            );
            if (!controller.isClosed && controller.hasListener) {
              controller.addError(ServerException(e.toString()));
            }
          }
        },
        onError: (err, stack) {
          AppLogger.error(
            'Realtime stream error for post: $postId, error: $err',
            error: err,
            stackTrace: stack,
          );
          if (!controller.isClosed && controller.hasListener) {
            controller.addError(ServerException(err.toString()));
          }
        },
        cancelOnError: false,
      );

      // Also seed the controller with the current comments (so subscriber gets initial snapshot).
      getComments(postId)
          .then((initial) {
            if (!controller.isClosed && controller.hasListener) {
              controller.add(initial);
            }
          })
          .catchError((e, st) {
            AppLogger.error(
              'Failed to fetch initial comments for stream seed: $e',
              error: e,
              stackTrace: st,
            );
            if (!controller.isClosed && controller.hasListener) {
              controller.addError(ServerException(e.toString()));
            }
          });

      // When the stream is cancelled, cancel the Supabase subscription and close controller.
      controller.onCancel = () async {
        await subscription.cancel();
        try {
          // supabase_flutter may manage subscriptions automatically, but we attempt to remove.
          // There's no direct `unsubscribe` here; cancelling the Dart subscription should suffice.
        } catch (_) {}
        if (!controller.isClosed) await controller.close();
        AppLogger.info('Comments stream cancelled for post: $postId');
      };

      return controller.stream;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to subscribe to comments stream for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Immediately throw as stream by returning Stream.error
      return Stream.error(ServerException(e.toString()));
    }
  }
}
