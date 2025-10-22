import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/followers/data/models/follower_model.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';

class FollowersRemoteDataSource {
  final SupabaseClient client;

  FollowersRemoteDataSource(this.client);

  Future<FollowerModel> followUser({
    required String followerId,
    required String followingId,
    required bool isFollowing,
  }) async {
    // This log will now be correct
    AppLogger.info(
      'Attempting to ${isFollowing ? 'follow' : 'unfollow'} user: $followingId by follower: $followerId',
    );
    try {
      // V-- LOGIC IS NOW SWAPPED --V
      if (isFollowing) {
        // isFollowing is TRUE, so we CREATE the follow
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
        // isFollowing is FALSE, so we DELETE the follow
        AppLogger.info(
          'Deleting follow relationship for follower: $followerId, following: $followingId',
        );
        await client.from('followers').delete().match({
          'follower_id': followerId,
          'following_id': followingId,
        });
        AppLogger.info('Follow relationship deleted successfully');
        // Return a dummy model since the row is gone
        return FollowerModel(
          id: '',
          followerId: followerId,
          followingId: followingId,
        );
      }
      // ^-- LOGIC IS NOW SWAPPED --^
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to ${isFollowing ? 'follow' : 'unfollow'} user: $followingId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<ProfileModel>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    AppLogger.info(
      'Fetching followers for user: $userId, page: $page, limit: $limit',
    );
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;
      final response = await client
          .from('followers')
          .select('profiles!followers_follower_id_fkey(*)')
          .eq('following_id', userId)
          .range(from, to);
      final followers = response
          .map((map) => ProfileModel.fromMap(map['profiles']))
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

  Future<List<ProfileModel>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    AppLogger.info(
      'Fetching following for user: $userId, page: $page, limit: $limit',
    );
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;
      final response = await client
          .from('followers')
          .select('profiles!followers_following_id_fkey(*)')
          .eq('follower_id', userId)
          .range(from, to);
      final following = response
          .map((map) => ProfileModel.fromMap(map['profiles']))
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
}
