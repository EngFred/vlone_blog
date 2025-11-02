import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/profile/data/models/profile_model.dart';
import 'package:vlone_blog_app/core/utils/image_compressor.dart';

class ProfileRemoteDataSource {
  final SupabaseClient client;
  ProfileRemoteDataSource(this.client);

  // Cached controllers & subscriptions keyed by userId
  final Map<String, StreamController<Map<String, dynamic>>>
  _profileControllers = {};
  final Map<String, RealtimeChannel> _profileChannels = {};

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
  /// Returns the fresh ProfileModel using an atomic update + select.
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
      File? compressedTempFile; // keep track to cleanup later

      if (profileImage != null) {
        AppLogger.info('Preparing profile image for upload for user: $userId');

        final file = File(profileImage.path);
        File fileToUpload = file;

        // Decide whether to attempt compression (fast stat)
        bool shouldAttemptCompression = false;
        try {
          final bytes = await file.length();
          shouldAttemptCompression =
              bytes > ImageCompressor.defaultMaxSizeBytes;
          AppLogger.info(
            'Profile image size=$bytes bytes, shouldCompress=$shouldAttemptCompression',
          );
        } catch (e) {
          AppLogger.warning(
            'Failed to stat profile image size; attempting compression as a fallback: $e',
          );
          shouldAttemptCompression = true;
        }

        if (shouldAttemptCompression) {
          try {
            // Compress silently; ImageCompressor will log its own details.
            final compressed = await ImageCompressor.compressIfNeeded(file);

            // If compressor returned a different file and it's smaller, use it.
            if (compressed.path != file.path) {
              AppLogger.info(
                'Profile image compressed: ${file.path} -> ${compressed.path}',
              );
              fileToUpload = compressed;
              compressedTempFile = compressed;
            } else {
              AppLogger.info(
                'Profile image compression did not reduce size; using original',
              );
            }
          } catch (e) {
            AppLogger.warning(
              'Profile image compression failed, will upload original: $e',
            );
            // continue with original file
          }
        } else {
          AppLogger.info(
            'Profile image below compression threshold; skipping compression',
          );
        }

        final fileExt = fileToUpload.path.split('.').last;
        final fileName = '${const Uuid().v4()}.$fileExt';
        final uploadPath = 'profiles/$userId/$fileName';

        try {
          await client.storage
              .from('profiles')
              .upload(uploadPath, fileToUpload);
          profileImageUrl = client.storage
              .from('profiles')
              .getPublicUrl(uploadPath);
          AppLogger.info(
            'Profile image uploaded successfully, url: $profileImageUrl',
          );
        } catch (e) {
          AppLogger.error('Failed to upload profile image: $e', error: e);
          // Cleanup compressed temp if present before throwing
          if (compressedTempFile != null) {
            try {
              if (await compressedTempFile.exists()) {
                await compressedTempFile.delete();
              }
            } catch (_) {}
          }
          throw ServerException(e.toString());
        } finally {
          // Best-effort cleanup of temporary compressed file if it exists and is different from original
          if (compressedTempFile != null) {
            try {
              if (await compressedTempFile.exists()) {
                await compressedTempFile.delete();
              }
              AppLogger.info(
                'Deleted temporary compressed profile image: ${compressedTempFile.path}',
              );
            } catch (e) {
              AppLogger.warning(
                'Failed to delete temporary compressed profile image: $e',
              );
            }
          }
        }
      }

      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (profileImageUrl != null) {
        updates['profile_image_url'] = profileImageUrl;
      }

      if (updates.isNotEmpty) {
        AppLogger.info('Applying profile updates for $userId: $updates');
        // Return updated row in one roundtrip
        final updated = await client
            .from('profiles')
            .update(updates)
            .eq('id', userId)
            .select()
            .single();

        AppLogger.info('Profile data updated successfully for user: $userId');
        return ProfileModel.fromMap(updated);
      } else {
        AppLogger.warning('No profile updates provided for user: $userId');
        // Just return current profile if nothing to update
        return await getProfile(userId);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update profile for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  /// Stream for profile updates (username, bio, profile_image_url, counts etc.)
  /// Returns a cached broadcast stream per userId.
  Stream<Map<String, dynamic>> streamProfileUpdates(String userId) {
    AppLogger.info('Requesting profile updates stream for user: $userId');

    // Return cached controller if present
    if (_profileControllers.containsKey(userId)) {
      AppLogger.info(
        'Returning existing profile updates stream for user: $userId',
      );
      return _profileControllers[userId]!.stream;
    }

    // FIX: Declare 'controller' first using 'late final' to allow self-reference in callbacks.
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () async {
        AppLogger.info('Listener attached to profile stream for user: $userId');
        // Seed with current profile
        try {
          final profile = await getProfile(userId);
          if (!controller.isClosed) controller.add(profile.toMap());
        } catch (e, st) {
          AppLogger.error(
            'Failed to seed profile stream for user: $userId, error: $e',
            error: e,
            stackTrace: st,
          );
          if (!controller.isClosed) {
            controller.addError(ServerException(e.toString()));
          }
        }
      },
      onCancel: () async {
        // Delay slightly and cleanup if no listeners
        await Future.delayed(const Duration(milliseconds: 50));
        if (!controller.hasListener) {
          AppLogger.info(
            'No listeners remain for profile stream, cleaning up for user: $userId',
          );
          final channel = _profileChannels.remove(userId);
          try {
            await channel?.unsubscribe();
          } catch (_) {}
          _profileControllers.remove(userId);
          if (!controller.isClosed) await controller.close();
        } else {
          AppLogger.info(
            'Profile stream still has listeners, skipping cleanup for user: $userId',
          );
        }
      },
    );

    // Setup realtime channel using Supabase Realtime "onPostgresChanges" for profile id filter
    try {
      final channel = client.channel(
        'profile_updates_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      final subscribed = channel
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
              try {
                AppLogger.info('Profile update received for user: $userId');
                final data = payload.newRecord;
                if (!controller.isClosed) {
                  controller.add(data);
                }
              } catch (e, st) {
                AppLogger.error(
                  'Failed to process profile update payload for user: $userId, error: $e',
                  error: e,
                  stackTrace: st,
                );
                if (!controller.isClosed) {
                  controller.addError(ServerException(e.toString()));
                }
              }
            },
          )
          .subscribe();

      _profileChannels[userId] = subscribed;
      _profileControllers[userId] = controller;

      return controller.stream;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to subscribe to profile updates for user: $userId, error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.error(ServerException(e.toString()));
    }
  }

  /// Global cleanup helper (call on app dispose if needed)
  Future<void> disposeAllProfileStreams() async {
    AppLogger.info('Disposing all profile streams');
    for (final channel in _profileChannels.values) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
    }
    _profileChannels.clear();

    for (final ctrl in _profileControllers.values) {
      try {
        if (!ctrl.isClosed) await ctrl.close();
      } catch (_) {}
    }
    _profileControllers.clear();
  }
}
