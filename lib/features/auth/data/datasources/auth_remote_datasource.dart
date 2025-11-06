import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/domain/errors/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/data/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthRemoteDataSource {
  final SupabaseClient client;
  final FlutterSecureStorage _secureStorage;

  static const String _cachedUserKey = 'cached_user_profile';

  /// Initializes the data source with a Supabase client and secure storage.
  /// The secure storage defaults to a new instance if not provided (for testing).
  AuthRemoteDataSource(this.client, [FlutterSecureStorage? secureStorage])
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Attempts to sign up a new user via email and password.
  ///
  /// Upon successful creation, it fetches the corresponding 'profiles' table entry
  /// (which is assumed to be created by a database trigger) and caches it.
  /// Throws [ServerException] if Supabase authentication or profile fetching fails.
  Future<UserModel> signUp({
    required String email,
    required String password,
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

      // The user profile is created via a database trigger for reliability.
      AppLogger.info(
        'Profile created by DB trigger. Fetching profile for ID: $userId',
      );

      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final userModel = UserModel.fromMap(profileData);

      // Caching the user profile immediately for offline access.
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

  /// Attempts to log in an existing user with email and password.
  ///
  /// On success, it fetches the user's profile from the database and caches it.
  /// Throws [ServerException] on authentication or profile fetching failure.
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

      // Caching the user profile immediately for offline access.
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

  /// Signs out the current user and clears all locally cached session and profile data.
  Future<void> logout() async {
    try {
      AppLogger.info('Attempting logout');
      await client.auth.signOut();

      // Clearing all cached data for a complete logout state.
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

  /// Fetches the profile of the currently logged-in user from the database.
  ///
  /// On network error ([SocketException] or other network issues), it attempts
  /// to return the cached user profile for offline access before throwing a
  /// [NetworkException].
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

      // Updating the cache with the latest data from the server.
      await _cacheUserProfile(userModel);

      AppLogger.info('Current user fetched successfully for ID: $userId');
      return userModel;
    } on SocketException catch (e) {
      AppLogger.warning(
        'Network error fetching user, trying cached profile: $e',
      );

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

      // Checking if the error is network-related to enable offline fallback.
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

  /// Restores a previously persisted Supabase session.
  ///
  /// This first performs a quick synchronous check for an active session. If none
  /// is found, it attempts to recover the session using the key stored in secure storage.
  /// Returns `true` if a session is found or successfully restored, `false` otherwise.
  Future<bool> restoreSession() async {
    try {
      AppLogger.info(
        'Attempting to restore session - checking currentSession first',
      );

      // Quick synchronous check avoids unnecessary async I/O if the session is active.
      if (client.auth.currentSession != null &&
          client.auth.currentUser != null) {
        AppLogger.info('Session already present in Supabase client');
        return true;
      }

      // Only attempting to recover if no session exists in memory.
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

  /// Caches the essential user profile data into secure storage.
  ///
  /// This is an optimization for fast access and robust offline mode.
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

  /// Retrieves the cached user profile from secure storage.
  /// Returns the [UserModel] or `null` if no cached data is found or decoding fails.
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

  /// Helper function to broadly detect network-related errors based on the error object or string representation.
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        error is SocketException;
  }
}
