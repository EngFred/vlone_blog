import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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

  /// Updates bio, username and/or profile image. Any parameter that is null is skipped.
  Future<ProfileModel> updateProfile({
    required String userId,
    String? username,
    String? bio,
    XFile? profileImage,
  }) async {
    AppLogger.info(
      'Updating profile for user: $userId, username: $username, bio: $bio, hasImage: ${profileImage != null}',
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
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (profileImageUrl != null)
        updates['profile_image_url'] = profileImageUrl;

      if (updates.isNotEmpty) {
        AppLogger.info('Applying profile updates for $userId: $updates');
        await client.from('profiles').update(updates).eq('id', userId);
        AppLogger.info('Profile data updated successfully for user: $userId');
      } else {
        AppLogger.warning('No profile updates provided for user: $userId');
      }

      // Return the fresh profile
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

  // ==================== REAL-TIME STREAMS ====================

  /// Stream for profile updates (username, bio, profile_image_url, counts etc.)
  /// Emits map with updated fields for the specific user
  Stream<Map<String, dynamic>> streamProfileUpdates(String userId) {
    AppLogger.info(
      'Setting up real-time stream for profile updates for user: $userId',
    );

    // Clean up existing channel and controller if needed
    // For simplicity, assuming one per datasource, but can make map if multiple
    RealtimeChannel? _profileChannel;
    StreamController<Map<String, dynamic>>? _profileController;

    _profileController = StreamController<Map<String, dynamic>>.broadcast();

    final channel = client.channel(
      'profile_updates_${userId}_${DateTime.now().millisecondsSinceEpoch}',
    );

    _profileChannel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            AppLogger.info('Profile update received for user: $userId');

            final data = payload.newRecord;

            if (!(_profileController?.isClosed ?? true)) {
              _profileController!.add(data);
            }
          },
        )
        .subscribe();

    // Cleanup when stream is done
    _profileController.stream.listen(
      null,
      onError: (error) {
        AppLogger.error(
          'Error in profile updates stream: $error',
          error: error,
        );
      },
      onDone: () {
        _profileChannel?.unsubscribe();
        _profileController?.close();
      },
    );

    return _profileController.stream;
  }
}
