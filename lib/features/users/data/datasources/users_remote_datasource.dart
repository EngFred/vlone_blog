import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/users/data/models/user_list_model.dart';

class UsersRemoteDataSource {
  final SupabaseClient client;
  UsersRemoteDataSource(this.client);

  Future<List<UserListModel>> getPaginatedUsers({
    required String currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    AppLogger.info(
      'Fetching paginated users via RPC for: $currentUserId (size: $pageSize, lastCreatedAt: $lastCreatedAt)',
    );
    try {
      final response = await client.rpc(
        'get_users_with_follow_status',
        params: {
          'current_user_id_input': currentUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );
      if (response == null) {
        AppLogger.info('RPC returned null for get_users_with_follow_status');
        return <UserListModel>[];
      }
      final users = (response as List)
          .map<UserListModel>(
            (map) => UserListModel.fromMap(map as Map<String, dynamic>),
          )
          .toList();
      AppLogger.info('Fetched ${users.length} users via RPC');
      return users;
    } catch (e, stackTrace) {
      // ... existing error handling ...
      AppLogger.error(
        'Failed to fetch paginated users via RPC: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is PostgrestException) {
        throw ServerException(e.message);
      }
      throw ServerException(e.toString());
    }
  }

  //Stream for new profile inserts (new users)
  Stream<UserListModel> streamNewUsers(String currentUserId) {
    AppLogger.info(
      'Setting up real-time stream for new users (profiles inserts)',
    );

    final streamController = StreamController<UserListModel>.broadcast();

    final channel = client.channel('realtime:profiles:inserts');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'profiles',
      callback: (payload) async {
        try {
          final newRec = payload.newRecord as Map<String, dynamic>?;

          if (newRec != null && newRec['id'] != currentUserId) {
            // Exclude self if somehow triggered
            // Construct from payload data directly
            final user = UserListModel.fromMap({
              ...newRec,
              'is_following':
                  false, // New user: current user isn't following yet
              // followers_count defaults to 0 in table, already in newRec
            });
            if (!streamController.isClosed) {
              streamController.add(user);
              AppLogger.info('New user emitted via real-time: ${user.id}');
            }
          }
        } catch (e, st) {
          AppLogger.error(
            'Error handling new profile insert: $e',
            error: e,
            stackTrace: st,
          );
          if (!streamController.isClosed) {
            streamController.addError(ServerException(e.toString()));
          }
        }
      },
    );

    channel.subscribe();

    // Cleanup on cancel
    streamController.onCancel = () async {
      await channel.unsubscribe();
      await streamController.close();
      AppLogger.info('New users stream unsubscribed and closed');
    };

    return streamController.stream;
  }
}
