import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/users/data/models/user_list_model.dart';

class UsersRemoteDataSource {
  final SupabaseClient client;

  UsersRemoteDataSource(this.client);

  Future<List<UserListModel>> getAllUsers(String currentUserId) async {
    AppLogger.info('Fetching all users via RPC for: $currentUserId');
    try {
      final response = await client.rpc(
        'get_users_with_follow_status',
        params: {'current_user_id_input': currentUserId},
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
        'Failed to fetch all users via RPC: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is PostgrestException) {
        throw ServerException(e.message);
      }
      throw ServerException(e.toString());
    }
  }
}
