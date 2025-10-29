import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/followers/data/models/follower_model.dart';
import 'package:vlone_blog_app/features/users/data/models/user_list_model.dart';

class FollowersRemoteDataSource {
  final SupabaseClient client;

  FollowersRemoteDataSource(this.client);

  /// Follow/unfollow a user. Returns the created follower row on follow,
  /// and a placeholder FollowerModel on unfollow to keep the same method shape.
  Future<FollowerModel> followUser({
    required String followerId,
    required String followingId,
    required bool isFollowing,
  }) async {
    AppLogger.info(
      'Attempting to ${isFollowing ? 'follow' : 'unfollow'} user: $followingId by follower: $followerId',
    );
    try {
      if (isFollowing) {
        AppLogger.info(
          'Creating follow relationship for follower: $followerId, following: $followingId',
        );
        final response = await client
            .from('followers')
            .insert({'follower_id': followerId, 'following_id': followingId})
            .select()
            .single();
        AppLogger.info('Follow relationship created successfully');
        return FollowerModel.fromMap(response);
      } else {
        AppLogger.info(
          'Deleting follow relationship for follower: $followerId, following: $followingId',
        );
        await client.from('followers').delete().match({
          'follower_id': followerId,
          'following_id': followingId,
        });
        AppLogger.info('Follow relationship deleted successfully');
        // Return a placeholder to keep contract (caller should typically refetch lists)
        return FollowerModel(
          id: '',
          followerId: followerId,
          followingId: followingId,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to ${isFollowing ? 'follow' : 'unfollow'} user: $followingId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<UserListModel>> getFollowers({
    required String userId,
    String? currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    AppLogger.info(
      'Fetching followers for user: $userId with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
    );
    try {
      final response = await client.rpc(
        'get_followers_with_follow_status',
        params: {
          'target_user_id': userId,
          'current_user_id_input': currentUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );

      if (response == null) return <UserListModel>[];

      final followers = (response as List)
          .map<UserListModel>(
            (map) => UserListModel.fromMap(map as Map<String, dynamic>),
          )
          .toList();
      AppLogger.info('Fetched ${followers.length} followers for user: $userId');
      return followers;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch followers for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<UserListModel>> getFollowing({
    required String userId,
    String? currentUserId,
    int pageSize = 20,
    DateTime? lastCreatedAt,
    String? lastId,
  }) async {
    AppLogger.info(
      'Fetching following for user: $userId with pagination: pageSize=$pageSize, lastCreatedAt=$lastCreatedAt, lastId=$lastId',
    );
    try {
      final response = await client.rpc(
        'get_following_with_follow_status',
        params: {
          'target_user_id': userId,
          'current_user_id_input': currentUserId,
          'page_size': pageSize,
          if (lastCreatedAt != null)
            'last_created_at': lastCreatedAt.toIso8601String(),
          if (lastId != null) 'last_id': lastId,
        },
      );

      if (response == null) return <UserListModel>[];

      final following = (response as List)
          .map<UserListModel>(
            (map) => UserListModel.fromMap(map as Map<String, dynamic>),
          )
          .toList();
      AppLogger.info('Fetched ${following.length} following for user: $userId');
      return following;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch following for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<bool> getFollowStatus({
    required String followerId,
    required String followingId,
  }) async {
    AppLogger.info(
      'Checking follow status for follower: $followerId, following: $followingId',
    );
    try {
      final response = await client.from('followers').select('id').match({
        'follower_id': followerId,
        'following_id': followingId,
      }).maybeSingle();
      final isFollowing = response != null;
      AppLogger.info('Follow status: $isFollowing');
      return isFollowing;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check follow status, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }
}
