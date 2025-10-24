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

  // Channel & controller for global comment events (moved from PostsRemoteDataSource)
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

  /// Returns a cached broadcast stream per postId. Multiple listeners share the same
  /// Supabase realtime subscription and controller.
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    AppLogger.info('Requesting comments stream for post: $postId');

    // Return existing controller's stream if already created.
    final existing = _controllers[postId];
    if (existing != null) {
      AppLogger.info('Returning existing comments stream for post: $postId');
      return existing.stream;
    }

    // FIX: Declare 'controller' first using 'late final' to allow self-reference in callbacks.
    late final StreamController<List<CommentModel>> controller;

    controller = StreamController<List<CommentModel>>.broadcast(
      onListen: () async {
        AppLogger.info(
          'Listener attached to comments stream for post: $postId',
        );
        // Seed initial comments
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
        // If there are no listeners left, cancel subscription and remove controller.
        // Small delay to avoid flapping if listeners reattach immediately.
        await Future.delayed(const Duration(milliseconds: 50));
        if (!controller.hasListener) {
          AppLogger.info(
            'No listeners remain for comments stream, cleaning up for post: $postId',
          );
          await _subscriptions[postId]?.cancel();
          _subscriptions.remove(postId);
          _controllers.remove(postId);
          if (!controller.isClosed) await controller.close();
        } else {
          AppLogger.info(
            'Listeners still present, skipping cleanup for post: $postId',
          );
        }
      },
    );

    // Setup realtime subscription
    try {
      final realtimeStream = client
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('post_id', postId);

      final sub = realtimeStream.listen(
        (payloadList) async {
          // Supabase realtime emits list of records; we only need payload events.
          // But Supabase Dart sometimes forwards a single record as a Map — handle both.
          try {
            // payloadList could be a List or a Map depending on event; defensively handle.
            // We will inspect the payload to detect insert/update/delete then modify cached list.
            if (_controllers[postId] != null &&
                !_controllers[postId]!.isClosed) {
              // try to get last emitted value if available by waiting zero and catching error if none
              // There's no direct API to peek; we will keep an in-memory cache by capturing last add.
            }

            // To keep code simple and reliable, attempt to parse payload and try incremental update,
            // otherwise fall back to full refetch.
            bool handledIncrementally = false;
            // payloadList might be e.g. [{'id':..., ...}] or a Map with event/etc.
            dynamic payload = payloadList;
            if (payload is List && payload.isNotEmpty) {
              payload = payload.first;
            }

            // If Supabase realtime payloads include `$type` or `eventType`, try to use them.
            // Supabase's onPostgresChanges callback typically provides a structured payload,
            // but since we're listening to client.from(...).stream(), we get raw records.
            // Best-effort: if payload has 'id' and 'created_at', treat as an insert and append.
            if (payload is Map<String, dynamic>) {
              final Map<String, dynamic> record = payload;
              // If record contains a 'deleted' marker or only oldRecord present, fall back to refetch.
              if (record.containsKey('id') &&
                  record.containsKey('created_at')) {
                // We'll attempt to append the single new comment to current snapshot if possible.
                try {
                  // If controller has a last known value, we can merge; otherwise refetch.
                  // There's no direct API to peek last emitted list, so we will refetch when unsure.
                  // However, we can optimistically add if controller hasListener (client expects near-realtime).
                  if (!controller.isClosed && controller.hasListener) {
                    // Fetch current list, append the new comment and emit.
                    // We use getComments which is authoritative — this still refetches, but only for inserts.
                    final refreshed = await getComments(postId);
                    if (!controller.isClosed) controller.add(refreshed);
                    handledIncrementally = true;
                  }
                } catch (_) {
                  handledIncrementally = false;
                }
              }
            }

            if (!handledIncrementally) {
              // Fallback: refetch whole view on unexpected payloads.
              AppLogger.info(
                'Comments stream: fallback refetch for post: $postId',
              );
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
      // Return Stream.error to match original behavior for callers subscribing immediately.
      return Stream.error(ServerException(e.toString()));
    }
  }

  /// [MOVED FROM POSTS_REMOTE_DATA_SOURCE]
  /// Stream for all comment insert events.
  /// Useful for updating UI counts on a feed.
  Stream<Map<String, dynamic>> streamCommentEvents() {
    AppLogger.info('Setting up real-time stream for global comment events');

    if (_commentsController != null && !_commentsController!.isClosed) {
      AppLogger.info('Returning existing global comments stream');
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

  /// Cleanup helper to dispose all controllers and subscriptions.
  Future<void> disposeAllStreams() async {
    AppLogger.info('Disposing all comments streams');

    // Dispose per-post streams
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

    // [ADDED] Dispose global comment event stream
    AppLogger.info('Disposing global comment event stream');
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
