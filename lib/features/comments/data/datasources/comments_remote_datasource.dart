import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/comments/data/models/comment_model.dart';

class CommentsRemoteDataSource {
  final SupabaseClient client;
  CommentsRemoteDataSource(this.client);

  // Cached controllers, channels, & local lists for getCommentsStream (per-post)
  final Map<String, StreamController<List<CommentModel>>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, List<CommentModel>> _localComments = {};

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

  Future<List<CommentModel>> getComments(
    String postId, {
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    AppLogger.info(
      'Fetching comments for post (RPC): $postId with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
    );
    try {
      // Call the paginated Postgres function
      final response = await client.rpc(
        'get_comments_with_user_status',
        params: {
          'p_post_id': postId,
          'p_current_user_id':
              null, // Optional, for future user-specific status like is_liked
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );

      // Normalize possible response shapes
      List<dynamic> rows;
      if (response == null) {
        rows = <dynamic>[];
      } else if (response is List) {
        rows = response;
      } else if (response is Map && response.values.isNotEmpty) {
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

  /// Fetches a single comment with profile info from the view
  Future<CommentModel> getSingleComment(String commentId) async {
    try {
      final response = await client
          .from('comments_view')
          .select()
          .eq('id', commentId)
          .single();
      // ignore: unnecessary_null_comparison
      if (response == null || response.isEmpty) {
        throw const ServerException('Comment not found');
      }
      return CommentModel.fromMap(response);
    } catch (e) {
      AppLogger.error(
        'Failed to fetch single comment $commentId: $e',
        error: e,
      );
      throw ServerException(e.toString());
    }
  }

  /// Appends more comments to the local cache for a post and emits if stream active
  void appendMoreComments(String postId, List<CommentModel> more) {
    if (_localComments.containsKey(postId)) {
      _localComments[postId]!.addAll(more);
      final controller = _controllers[postId];
      if (controller != null && !controller.isClosed) {
        controller.add(_localComments[postId]!);
      }
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

    final controller = StreamController<List<CommentModel>>.broadcast();
    _controllers[postId] = controller;

    controller.onListen = () async {
      AppLogger.info('Listener attached to comments stream for post: $postId');
      try {
        final initial = await getComments(postId, pageSize: 20);
        _localComments[postId] = initial;
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
    };

    // Setup realtime delta listener
    final channel = client.channel('comments_post_$postId');
    _channels[postId] = channel;

    void handlePayload(PostgresChangePayload payload) async {
      try {
        final event = payload.eventType;
        if (event == PostgresChangeEvent.insert) {
          final newRec = payload.newRecord;
          final id = newRec['id'] as String?;
          if (id != null) {
            final comment = await getSingleComment(id);
            final local = _localComments[postId] ?? [];
            local.insert(0, comment);
            _localComments[postId] = local;
            if (!controller.isClosed) controller.add(local);
          }
        } else if (event == PostgresChangeEvent.update) {
          final newRec = payload.newRecord;
          final id = newRec['id'] as String?;
          if (id != null) {
            final updated = await getSingleComment(id);
            final local = _localComments[postId] ?? [];
            final index = local.indexWhere((c) => c.id == id);
            if (index != -1) {
              local[index] = updated;
              _localComments[postId] = local;
              if (!controller.isClosed) controller.add(local);
            }
          }
        } else if (event == PostgresChangeEvent.delete) {
          final oldRec = payload.oldRecord;
          final id = oldRec['id'] as String?;
          if (id != null) {
            final local = _localComments[postId] ?? [];
            local.removeWhere((c) => c.id == id);
            _localComments[postId] = local;
            if (!controller.isClosed) controller.add(local);
          }
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
    }

    // --- FIX START ---
    // Define the filter object as required by the new API
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'post_id',
      value: postId,
    );
    // --- FIX END ---

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: filter, // Use the filter object
          callback: handlePayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'comments',
          filter: filter, // Use the filter object
          callback: handlePayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: filter, // Use the filter object
          callback: handlePayload,
        )
        .subscribe();

    controller.onCancel = () async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!controller.hasListener) {
        AppLogger.info('No listeners remain, cleaning up for post: $postId');
        try {
          await _channels[postId]?.unsubscribe();
        } catch (_) {}
        _channels.remove(postId);
        _controllers.remove(postId);
        _localComments.remove(postId);
        if (!controller.isClosed) await controller.close();
      }
    };

    return controller.stream;
  }

  /// Global comment insert stream (for feed counters)
  Stream<Map<String, dynamic>> streamCommentEvents() {
    AppLogger.info('Setting up real-time stream for global comment events');
    if (_commentsController != null && !_commentsController!.isClosed) {
      return _commentsController!.stream;
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
    return _commentsController!.stream;
  }

  Future<void> disposeAllStreams() async {
    AppLogger.info('Disposing all comments streams');
    for (final channel in _channels.values) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
    }
    _channels.clear();

    for (final ctrl in _controllers.values) {
      try {
        if (!ctrl.isClosed) await ctrl.close();
      } catch (_) {}
    }
    _controllers.clear();
    _localComments.clear();

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
