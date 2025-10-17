import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
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
    try {
      if (isFollowing) {
        await client.from('followers').delete().match({
          'follower_id': followerId,
          'following_id': followingId,
        });
        return FollowerModel(
          id: '',
          followerId: followerId,
          followingId: followingId,
        ); // Dummy
      } else {
        final response = await client
            .from('followers')
            .insert({'follower_id': followerId, 'following_id': followingId})
            .select()
            .single();

        return FollowerModel.fromMap(response);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<ProfileModel>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('followers')
          .select('profiles!followers_follower_id_fkey(*)')
          .eq('following_id', userId)
          .range(from, to);

      return response
          .map((map) => ProfileModel.fromMap(map['profiles']))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<ProfileModel>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('followers')
          .select('profiles!followers_following_id_fkey(*)')
          .eq('follower_id', userId)
          .range(from, to);

      return response
          .map((map) => ProfileModel.fromMap(map['profiles']))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
