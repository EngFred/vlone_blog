import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/followers/data/models/follower_model.dart';
import 'package:vlone_blog_app/features/users/data/models/user_list_model.dart';

class FollowersRemoteDataSource {
  final SupabaseClient client;

  FollowersRemoteDataSource(this.client);

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
  }) async {
    AppLogger.info('Fetching followers for user: $userId');
    try {
      final response = await client.rpc(
        'get_followers_with_follow_status',
        params: {
          'current_user_id_input': currentUserId,
          'target_user_id': userId,
        },
      );
      final followers = response
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
  }) async {
    AppLogger.info('Fetching following for user: $userId');
    try {
      final response = await client.rpc(
        'get_following_with_follow_status',
        params: {
          'current_user_id_input': currentUserId,
          'target_user_id': userId,
        },
      );
      final following = response
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
