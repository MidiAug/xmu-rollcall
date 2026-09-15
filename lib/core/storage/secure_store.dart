import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over secure storage — no plaintext secrets on disk.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _backend = _FlutterSecureBackend(
          storage ??
              const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
              ),
        );

  /// In-memory store for unit tests (no platform channel).
  SecureStore.memory([Map<String, String>? seed])
      : _backend = _MemorySecureBackend(Map<String, String>.of(seed ?? {}));

  final _SecureBackend _backend;

  static const keyDeviceId = 'device_id';
  static const keySessionCookies = 'session_cookies_json';
  static const keyUserDisplayName = 'user_display_name';
  static const keyUserId = 'user_id';
  static const keyLastUsername = 'last_username';

  /// Prefix for assist session cookie blobs (`assist_session_cookies_<userId>`).
  static const assistSessionCookiePrefix = 'assist_session_cookies_';

  Future<String?> read(String key) => _backend.read(key);

  Future<void> write(String key, String value) => _backend.write(key, value);

  Future<void> delete(String key) => _backend.delete(key);

  Future<void> deleteAll(Iterable<String> keys) async {
    for (final key in keys) {
      await _backend.delete(key);
    }
  }
}

abstract class _SecureBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureBackend implements _SecureBackend {
  _FlutterSecureBackend(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _MemorySecureBackend implements _SecureBackend {
  _MemorySecureBackend(this._map);
  final Map<String, String> _map;

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}
