import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/users/data/models/user_list_model.dart';

class UsersRemoteDataSource {
  final SupabaseClient client;
  UsersRemoteDataSource(this.client);

  /// Fetches a paginated list of all users, excluding the `currentUserId`.
  ///
  /// Utilizes a Postgres RPC function (`get_users_with_follow_status`) for
  /// efficient cursor-based pagination and injection of the `currentUserId`'s
  /// follow status relative to each user in the list.
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

  /// Provides a real-time stream of newly created user profiles (new sign-ups).
  ///
  /// Listens for `INSERT` events on the 'profiles' table and emits a [UserListModel]
  /// for the new user, defaulting `is_following` to `false`.
  Stream<UserListModel> streamNewUsers(String currentUserId) {
    AppLogger.info(
      'Setting up real-time stream for new users (profiles inserts)',
    );

    final streamController = StreamController<UserListModel>.broadcast();

    // Using a dedicated channel for profiles inserts.
    final channel = client.channel('realtime:profiles:inserts');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'profiles',
      callback: (payload) async {
        try {
          final newRec = payload.newRecord as Map<String, dynamic>?;

          if (newRec != null && newRec['id'] != currentUserId) {
            // Excluding the current user's own profile insert event.
            // Constructing the model by merging profile data with default list properties.
            final user = UserListModel.fromMap({
              ...newRec,
              'is_following':
                  false, // Assumption: User is new, so current user is not following.
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

    // Cleanup logic: unsubscribe and close on stream cancellation.
    streamController.onCancel = () async {
      await channel.unsubscribe();
      await streamController.close();
      AppLogger.info('New users stream unsubscribed and closed');
    };

    return streamController.stream;
  }
}
