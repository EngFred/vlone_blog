import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';

class ProfileRemoteDataSource {
  final SupabaseClient client;

  ProfileRemoteDataSource(this.client);

  Future<ProfileModel> getProfile(String userId) async {
    try {
      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return ProfileModel.fromMap(profileData);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<ProfileModel> updateProfile({
    required String userId,
    String? bio,
    XFile? profileImage, // Use image_picker's XFile for upload
  }) async {
    try {
      String? profileImageUrl;
      if (profileImage != null) {
        final file = File(profileImage.path);
        final fileExt = profileImage.path.split('.').last;
        final fileName = '${const Uuid().v4()}.$fileExt';
        final uploadPath = 'profiles/$userId/$fileName';
        await client.storage.from('profiles').upload(uploadPath, file);
        profileImageUrl = client.storage
            .from('profiles')
            .getPublicUrl(uploadPath);
      }

      final updates = <String, dynamic>{};
      if (bio != null) updates['bio'] = bio;
      if (profileImageUrl != null)
        updates['profile_image_url'] = profileImageUrl;

      await client.from('profiles').update(updates).eq('id', userId);

      // Fetch updated profile
      return await getProfile(userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
