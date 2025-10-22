import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/data/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRemoteDataSource {
  final SupabaseClient client;
  final FlutterSecureStorage _secureStorage;

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
      AppLogger.info('Inserting profile for user ID: $userId');
      await client.from('profiles').insert({
        'id': userId,
        'email': email,
        'username': username,
      });

      AppLogger.info('Signup successful for user ID: $userId');
      return UserModel(id: userId, email: email, username: username);
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

      AppLogger.info('Login successful for user ID: $userId');
      return UserModel.fromMap(profileData);
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
      await _secureStorage.delete(key: 'supabase_persisted_session');
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

      AppLogger.info('Current user fetched successfully for ID: $userId');
      return UserModel.fromMap(profileData);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error fetching current user: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(e.toString());
    }
  }

  /// Attempts to restore an existing persisted session.
  /// Returns true if a session was successfully restored.
  Future<bool> restoreSession() async {
    try {
      AppLogger.info(
        'Attempting to restore session - checking currentSession first',
      );
      // If supabase client already has a session, nothing to do
      if (client.auth.currentSession != null &&
          client.auth.currentUser != null) {
        AppLogger.info('Session already present in Supabase client');
        return true;
      }

      // Read persisted session JSON from secure storage
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
}
