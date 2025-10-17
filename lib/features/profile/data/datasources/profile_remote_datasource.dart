import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';

class ProfileRemoteDataSource {
  final SupabaseClient client;

  ProfileRemoteDataSource(this.client);

  Future<ProfileModel> getProfile(String userId) async {
    AppLogger.info('Fetching profile for user: $userId');
    try {
      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      AppLogger.info('Profile fetched successfully for user: $userId');
      return ProfileModel.fromMap(profileData);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch profile for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<ProfileModel> updateProfile({
    required String userId,
    String? bio,
    XFile? profileImage,
  }) async {
    AppLogger.info(
      'Updating profile for user: $userId, bio: $bio, hasImage: ${profileImage != null}',
    );
    try {
      String? profileImageUrl;
      if (profileImage != null) {
        AppLogger.info('Uploading profile image for user: $userId');
        final file = File(profileImage.path);
        final fileExt = profileImage.path.split('.').last;
        final fileName = '${const Uuid().v4()}.$fileExt';
        final uploadPath = 'profiles/$userId/$fileName';
        await client.storage.from('profiles').upload(uploadPath, file);
        profileImageUrl = client.storage
            .from('profiles')
            .getPublicUrl(uploadPath);
        AppLogger.info(
          'Profile image uploaded successfully, url: $profileImageUrl',
        );
      }

      final updates = <String, dynamic>{};
      if (bio != null) updates['bio'] = bio;
      if (profileImageUrl != null)
        updates['profile_image_url'] = profileImageUrl;

      if (updates.isNotEmpty) {
        AppLogger.info(
          'Updating profile data for user: $userId with updates: $updates',
        );
        await client.from('profiles').update(updates).eq('id', userId);
        AppLogger.info('Profile data updated successfully for user: $userId');
      } else {
        AppLogger.warning('No profile updates provided for user: $userId');
      }

      AppLogger.info('Fetching updated profile for user: $userId');
      return await getProfile(userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update profile for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      AppLogger.info(
        'Fetching user posts for $userId, page: $page, limit: $limit',
      );
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      AppLogger.info('User posts fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching user posts: $e', error: e);
      throw ServerException(e.toString());
    }
  }
}
