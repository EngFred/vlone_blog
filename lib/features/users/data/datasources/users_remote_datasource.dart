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
      // This is the new, safer way.
      final response = await client.rpc(
        'get_users_with_follow_status',
        params: {'current_user_id_input': currentUserId},
      );

      // The response is already a list of maps, just like .select()
      final users = response
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
      // Handle PostgrestErrors specifically if you want
      if (e is PostgrestException) {
        throw ServerException(e.message);
      }
      throw ServerException(e.toString());
    }
  }
}
