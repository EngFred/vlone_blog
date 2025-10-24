import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

class LikesRemoteDataSource {
  final SupabaseClient client;

  RealtimeChannel? _likesChannel;
  StreamController<Map<String, dynamic>>? _likesController;

  LikesRemoteDataSource(this.client);

  /// Handles liking or unliking a post.
  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      AppLogger.info(
        'Attempting to ${isLiked ? 'like' : 'unlike'} post: $postId by user: $userId',
      );

      if (isLiked) {
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await client.from('likes').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
      }

      AppLogger.info('Like/unlike successful for post: $postId');
    } catch (e) {
      AppLogger.error('Error liking post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  /// Stream for all like/unlike events.
  /// Useful for updating UI counts on a feed.
  Stream<Map<String, dynamic>> streamLikeEvents() {
    AppLogger.info('Setting up real-time stream for like events');

    if (_likesController != null && !_likesController!.isClosed) {
      AppLogger.info('Returning existing likes stream');
      return _likesController!.stream.handleError((error) {
        AppLogger.error('Error in likes stream: $error', error: error);
      });
    }

    _likesController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'likes_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _likesChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            try {
              AppLogger.info('Like event received: ${payload.eventType}');

              final record = payload.eventType == PostgresChangeEvent.delete
                  ? payload.oldRecord
                  : payload.newRecord;

              final data = {
                'event': payload.eventType.name,
                'post_id': record['post_id'],
                'user_id': record['user_id'],
              };

              if (!(_likesController?.isClosed ?? true)) {
                _likesController!.add(data);
              }
            } catch (e, st) {
              AppLogger.error(
                'Error handling like payload: $e',
                error: e,
                stackTrace: st,
              );
              if (!(_likesController?.isClosed ?? true)) {
                _likesController!.addError(ServerException(e.toString()));
              }
            }
          },
        )
        .subscribe();

    _likesController!.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_likesController?.hasListener ?? false)) {
        try {
          await _likesChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_likesController?.isClosed ?? true))
            await _likesController?.close();
        } catch (_) {}
        _likesChannel = null;
        _likesController = null;
        AppLogger.info('Likes stream cancelled and cleaned up');
      }
    };

    return _likesController!.stream.handleError((error) {
      AppLogger.error('Error in likes stream: $error', error: error);
    });
  }

  /// Cleanup method
  void dispose() {
    AppLogger.info('Disposing LikesRemoteDataSource');
    try {
      _likesChannel?.unsubscribe();
    } catch (_) {}
    try {
      _likesController?.close();
    } catch (_) {}
  }
}
