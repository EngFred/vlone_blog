import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsLocalDataSource {
  final FlutterSecureStorage storage;

  SettingsLocalDataSource(this.storage);

  static const String _themeKey = 'theme_mode';

  Future<String?> getThemeMode() async {
    return await storage.read(key: _themeKey);
  }

  Future<void> saveThemeMode(String mode) async {
    await storage.write(key: _themeKey, value: mode);
  }
}
