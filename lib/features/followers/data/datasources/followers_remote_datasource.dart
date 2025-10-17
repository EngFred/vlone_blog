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
    AppLogger.info(
      'Attempting to ${isFollowing ? 'unfollow' : 'follow'} user: $followingId by follower: $followerId',
    );
    try {
      if (isFollowing) {
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
      } else {
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
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to ${isFollowing ? 'unfollow' : 'follow'} user: $followingId, error: $e',
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
