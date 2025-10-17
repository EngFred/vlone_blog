import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
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
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.session == null) {
        throw const ServerException('Signup failed. Please try again.');
      }

      final userId = authResponse.user!.id;
      await client.from('profiles').insert({
        'id': userId,
        'email': email,
        'username': username,
      });

      // For signup, we don't have full profile yet, so return partial model
      return UserModel(id: userId, email: email, username: username);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (authResponse.session == null) {
        throw const ServerException('Login failed. Invalid credentials.');
      }

      final userId = authResponse.user!.id;
      final profileData = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromMap(profileData);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<UserModel> getCurrentUser() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('No user logged in');
    }

    final profileData = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return UserModel.fromMap(profileData);
  }
}
