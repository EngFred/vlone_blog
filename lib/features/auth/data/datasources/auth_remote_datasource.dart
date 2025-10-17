import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/data/models/user_model.dart';

class AuthRemoteDataSource {
  final SupabaseClient client;

  AuthRemoteDataSource(this.client);

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

      // No need to check session == null anymore, as confirmation is disabled
      if (authResponse.session == null) {
        AppLogger.warning(
          'Signup response has no session (unexpected after disabling confirmation)',
        );
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
      // For signup, we don't have full profile yet, so return partial model
      return UserModel(id: userId, email: email, username: username);
    } on AuthException catch (e) {
      AppLogger.error('AuthException during signup: ${e.message}', error: e);
      throw ServerException(e.message);
    } catch (e) {
      AppLogger.error('Unexpected error during signup: $e', error: e);
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
      if (authResponse.session == null) {
        AppLogger.warning('Login response has no session');
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
    } on AuthException catch (e) {
      AppLogger.error('AuthException during login: ${e.message}', error: e);
      throw ServerException(e.message);
    } catch (e) {
      AppLogger.error('Unexpected error during login: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      AppLogger.info('Attempting logout');
      await client.auth.signOut();
      AppLogger.info('Logout successful');
    } catch (e) {
      AppLogger.error('Error during logout: $e', error: e);
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
    } catch (e) {
      AppLogger.error('Error fetching current user: $e', error: e);
      throw ServerException(e.toString());
    }
  }
}
