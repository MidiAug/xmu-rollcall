import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over secure storage — no plaintext secrets on disk.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const keyDeviceId = 'device_id';
  static const keySessionCookies = 'session_cookies_json';
  static const keyUserDisplayName = 'user_display_name';
  static const keyUserId = 'user_id';
  static const keyLastUsername = 'last_username';

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll(Iterable<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }
}
