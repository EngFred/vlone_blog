import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

/// A [LocalStorage] implementation that uses [FlutterSecureStorage] to
/// persist the Supabase session.
class SecureStorage implements LocalStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    AppLogger.info('Initializing secure storage for Supabase');
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: 'supabase_persisted_session');
    AppLogger.info('Checking access token in secure storage: ${token != null}');
    return token != null;
  }

  @override
  Future<String?> accessToken() async {
    final token = await _storage.read(key: 'supabase_persisted_session');
    AppLogger.info('Retrieved access token from secure storage');
    return token;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    AppLogger.info('Persisting session to secure storage');
    await _storage.write(
      key: 'supabase_persisted_session',
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    AppLogger.info('Removing persisted session from secure storage');
    await _storage.delete(key: 'supabase_persisted_session');
  }
}
