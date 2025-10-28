import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/comments/data/models/comment_model.dart';

class CommentsRemoteDataSource {
  final SupabaseClient client;
  CommentsRemoteDataSource(this.client);

  // Cached controllers & subscriptions for getCommentsStream (per-post)
  final Map<String, StreamController<List<CommentModel>>> _controllers = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Channel & controller for global comment events
  RealtimeChannel? _commentsChannel;
  StreamController<Map<String, dynamic>>? _commentsController;

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
    AppLogger.info('Fetching initial comments for post (RPC): $postId');
    try {
      // Call the canonical RPC that guarantees ORDER BY created_at DESC and includes replies_count & profile info
      final response = await client.rpc(
        'get_comments_view_for_post',
        params: {'p_post_id': postId},
      );

      // Normalize possible response shapes
      List<dynamic> rows;
      if (response == null) {
        rows = <dynamic>[];
      } else if (response is List) {
        rows = response;
      } else if (response is Map && response.values.isNotEmpty) {
        // supabase sometimes wraps results like {'get_comments_view_for_post': [ ... ]}
        final firstVal = response.values.first;
        rows = firstVal is List ? firstVal : [firstVal];
      } else {
        rows = [response];
      }

      final comments = rows
          .map((r) => CommentModel.fromMap(r as Map<String, dynamic>))
          .toList();

      AppLogger.info(
        'Fetched ${comments.length} comments for post: $postId (RPC)',
      );
      return comments;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch comments for post (RPC): $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  /// Returns a cached broadcast stream per postId.
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    AppLogger.info('Requesting comments stream for post: $postId');

    final existing = _controllers[postId];
    if (existing != null) {
      AppLogger.info('Returning existing comments stream for post: $postId');
      return existing.stream;
    }

    late final StreamController<List<CommentModel>> controller;

    controller = StreamController<List<CommentModel>>.broadcast(
      onListen: () async {
        AppLogger.info(
          'Listener attached to comments stream for post: $postId',
        );
        try {
          final initial = await getComments(postId);
          if (!controller.isClosed) controller.add(initial);
        } catch (e, st) {
          AppLogger.error(
            'Failed to seed initial comments for post: $postId, error: $e',
            error: e,
            stackTrace: st,
          );
          if (!controller.isClosed) {
            controller.addError(ServerException(e.toString()));
          }
        }
      },
      onCancel: () async {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!controller.hasListener) {
          AppLogger.info('No listeners remain, cleaning up for post: $postId');
          await _subscriptions[postId]?.cancel();
          _subscriptions.remove(postId);
          _controllers.remove(postId);
          if (!controller.isClosed) await controller.close();
        }
      },
    );

    // Realtime: listen to changes on the COMMENTS TABLE (table triggers always fire).
    try {
      final realtimeStream = client
          .from('comments') // listen on table not view
          .stream(primaryKey: ['id'])
          .eq('post_id', postId);

      final sub = realtimeStream.listen(
        (payloadList) async {
          try {
            // Normalize payload shape
            dynamic payload = payloadList;
            if (payload is List && payload.isNotEmpty) {
              payload = payload.first;
            }

            if (payload is Map<String, dynamic> && payload.containsKey('id')) {
              // Simple & safe: refetch canonical (server-ordered) list on any change
              final refreshed = await getComments(postId);
              if (!controller.isClosed) controller.add(refreshed);
            }
          } catch (e, st) {
            AppLogger.error(
              'Failed to process realtime comment payload for post: $postId, error: $e',
              error: e,
              stackTrace: st,
            );
            if (!controller.isClosed && controller.hasListener) {
              controller.addError(ServerException(e.toString()));
            }
          }
        },
        onError: (err, st) {
          AppLogger.error(
            'Realtime stream error for post: $postId, error: $err',
            error: err,
            stackTrace: st,
          );
          if (!controller.isClosed && controller.hasListener) {
            controller.addError(ServerException(err.toString()));
          }
        },
        cancelOnError: false,
      );

      // Cache controller and subscription
      _controllers[postId] = controller;
      _subscriptions[postId] = sub;

      return controller.stream;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to subscribe to comments stream for post: $postId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.error(ServerException(e.toString()));
    }
  }

  /// Global comment insert stream (for feed counters)
  Stream<Map<String, dynamic>> streamCommentEvents() {
    AppLogger.info('Setting up real-time stream for global comment events');

    if (_commentsController != null && !_commentsController!.isClosed) {
      return _commentsController!.stream.handleError((error) {
        AppLogger.error(
          'Error in global comments stream: $error',
          error: error,
        );
      });
    }

    _commentsController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'comments_updates_${DateTime.now().millisecondsSinceEpoch}',
    );

    _commentsChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            try {
              AppLogger.info(
                'Comment event received on post: ${payload.newRecord['post_id']}',
              );

              final data = {
                'event': 'INSERT',
                'post_id': payload.newRecord['post_id'],
                'user_id': payload.newRecord['user_id'],
                'comment_id': payload.newRecord['id'],
              };

              if (!(_commentsController?.isClosed ?? true)) {
                _commentsController!.add(data);
              }
            } catch (e, st) {
              AppLogger.error(
                'Error handling comment payload: $e',
                error: e,
                stackTrace: st,
              );
              if (!(_commentsController?.isClosed ?? true)) {
                _commentsController!.addError(ServerException(e.toString()));
              }
            }
          },
        )
        .subscribe();

    _commentsController!.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!(_commentsController?.hasListener ?? false)) {
        try {
          await _commentsChannel?.unsubscribe();
        } catch (_) {}
        try {
          if (!(_commentsController?.isClosed ?? true)) {
            await _commentsController?.close();
          }
        } catch (_) {}
        _commentsChannel = null;
        _commentsController = null;
        AppLogger.info('Global comments stream cancelled and cleaned up');
      }
    };

    return _commentsController!.stream.handleError((error) {
      AppLogger.error('Error in global comments stream: $error', error: error);
    });
  }

  Future<void> disposeAllStreams() async {
    AppLogger.info('Disposing all comments streams');

    for (final sub in _subscriptions.values) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();

    for (final ctrl in _controllers.values) {
      try {
        if (!ctrl.isClosed) await ctrl.close();
      } catch (_) {}
    }
    _controllers.clear();

    try {
      await _commentsChannel?.unsubscribe();
    } catch (_) {}
    _commentsChannel = null;

    try {
      if (!(_commentsController?.isClosed ?? true)) {
        await _commentsController?.close();
      }
    } catch (_) {}
    _commentsController = null;
  }
}
