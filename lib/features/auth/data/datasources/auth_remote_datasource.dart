import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/data/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthRemoteDataSource {
  final SupabaseClient client;
  final FlutterSecureStorage _secureStorage;

  static const String _cachedUserKey = 'cached_user_profile';

  AuthRemoteDataSource(this.client, [FlutterSecureStorage? secureStorage])
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      AppLogger.info('Attempting signup for email: $email');
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.session == null || authResponse.user == null) {
        AppLogger.warning('Signup response has no session or user');
        throw const ServerException(
          'Signup failed unexpectedly. Please try again.',
        );
      }

      final userId = authResponse.user!.id;

      // ✅ OPTIMIZED: Database trigger creates profile, we just fetch it
      // Removed client-side profile insertion for reliability
      AppLogger.info(
        'Profile created by DB trigger. Fetching profile for ID: $userId',
      );

      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final userModel = UserModel.fromMap(profileData);

      // ✅ Cache immediately for offline access
      await _cacheUserProfile(userModel);

      AppLogger.info('Signup successful for user ID: $userId');
      return userModel;
    } on AuthException catch (e, stackTrace) {
      AppLogger.error(
        'AuthException during signup: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error during signup: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Attempting login for email: $email');
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session == null || authResponse.user == null) {
        AppLogger.warning('Login response has no session or user');
        throw const ServerException('Login failed. Invalid credentials.');
      }

      final userId = authResponse.user!.id;
      AppLogger.info('Fetching profile for user ID: $userId');
      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final userModel = UserModel.fromMap(profileData);

      // ✅ Cache immediately for offline access
      await _cacheUserProfile(userModel);

      AppLogger.info('Login successful for user ID: $userId');
      return userModel;
    } on AuthException catch (e, stackTrace) {
      AppLogger.error(
        'AuthException during login: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error during login: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      AppLogger.info('Attempting logout');
      await client.auth.signOut();
      // ✅ Clear all cached data
      await _secureStorage.delete(key: 'supabase_persisted_session');
      await _secureStorage.delete(key: _cachedUserKey);
      AppLogger.info('Logout successful');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error during logout: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  Future<UserModel> getCurrentUser() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.warning('No current user ID found');
      throw const ServerException('No user logged in');
    }

    try {
      AppLogger.info('Fetching current user profile for ID: $userId');
      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final userModel = UserModel.fromMap(profileData);

      // ✅ Update cache with latest data
      await _cacheUserProfile(userModel);

      AppLogger.info('Current user fetched successfully for ID: $userId');
      return userModel;
    } on SocketException catch (e) {
      AppLogger.warning(
        'Network error fetching user, trying cached profile: $e',
      );
      // ✅ OPTIMIZATION: Return cached profile for offline mode
      final cachedUser = await _getCachedUserProfile();
      if (cachedUser != null) {
        AppLogger.info('Returning cached user profile for offline access');
        return cachedUser;
      }
      throw NetworkException(
        'No internet connection and no cached profile available',
      );
    } catch (e) {
      AppLogger.error('Error fetching current user: $e');

      // ✅ Check if it's a network-related error
      if (_isNetworkError(e)) {
        final cachedUser = await _getCachedUserProfile();
        if (cachedUser != null) {
          AppLogger.info('Network error, returning cached user profile');
          return cachedUser;
        }
        throw NetworkException(
          'No internet connection and no cached profile available',
        );
      }

      throw ServerException(e.toString());
    }
  }

  /// ✅ OPTIMIZED: Check existing session synchronously first
  /// This avoids unnecessary async calls when session already exists
  Future<bool> restoreSession() async {
    try {
      AppLogger.info(
        'Attempting to restore session - checking currentSession first',
      );

      // ✅ PERFORMANCE: Quick synchronous check
      if (client.auth.currentSession != null &&
          client.auth.currentUser != null) {
        AppLogger.info('Session already present in Supabase client');
        return true;
      }

      // ✅ Only try to recover if no session exists
      final persisted = await _secureStorage.read(
        key: 'supabase_persisted_session',
      );

      if (persisted == null || persisted.trim().isEmpty) {
        AppLogger.info('No persisted session found in secure storage');
        return false;
      }

      AppLogger.info('Found persisted session, attempting recoverSession');
      await client.auth.recoverSession(persisted);

      final hasSession = client.auth.currentUser != null;
      AppLogger.info(
        'Session restoration ${hasSession ? 'successful' : 'failed'}',
      );
      return hasSession;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error restoring session: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// ✅ OPTIMIZATION: Cache user profile for offline access
  /// Stores essential user data in secure storage
  Future<void> _cacheUserProfile(UserModel user) async {
    try {
      final userJson = jsonEncode({
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'bio': user.bio,
        'profile_image_url': user.profileImageUrl,
        'followers_count': user.followersCount,
        'following_count': user.followingCount,
        'posts_count': user.postsCount,
        'total_likes': user.totalLikes,
      });
      await _secureStorage.write(key: _cachedUserKey, value: userJson);
      AppLogger.info('User profile cached for offline access');
    } catch (e) {
      AppLogger.warning('Failed to cache user profile: $e');
    }
  }

  /// ✅ Retrieve cached user profile for offline mode
  Future<UserModel?> _getCachedUserProfile() async {
    try {
      final cachedJson = await _secureStorage.read(key: _cachedUserKey);
      if (cachedJson == null) return null;

      final map = jsonDecode(cachedJson) as Map<String, dynamic>;
      return UserModel.fromMap(map);
    } catch (e) {
      AppLogger.warning('Failed to retrieve cached user profile: $e');
      return null;
    }
  }

  /// ✅ Helper to detect network-related errors
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        error is SocketException;
  }
}
