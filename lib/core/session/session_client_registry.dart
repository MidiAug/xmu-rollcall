import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

typedef TronHttpClientFactory = TronHttpClient Function({
  required SecureStore store,
  required SessionKey sessionKey,
  required RateLimiter rateLimiter,
});

/// Caches one [TronHttpClient] per [SessionKey], sharing a [RateLimiter].
class SessionClientRegistry {
  SessionClientRegistry({
    required this.store,
    RateLimiter? rateLimiter,
    TronHttpClientFactory? createClient,
  })  : _limiter = rateLimiter ?? RateLimiter(),
        _createClient = createClient ?? _defaultCreate;

  final SecureStore store;
  final RateLimiter _limiter;
  final TronHttpClientFactory _createClient;
  final Map<String, TronHttpClient> _clients = {};

  static TronHttpClient _defaultCreate({
    required SecureStore store,
    required SessionKey sessionKey,
    required RateLimiter rateLimiter,
  }) {
    return TronHttpClient(
      store: store,
      sessionKey: sessionKey,
      rateLimiter: rateLimiter,
    );
  }

  TronHttpClient owner() => forKey(SessionKey.owner);

  TronHttpClient forKey(SessionKey key) {
    return _clients.putIfAbsent(
      key.storageId,
      () => _createClient(
        store: store,
        sessionKey: key,
        rateLimiter: _limiter,
      ),
    );
  }

  /// Drop assist client from cache and clear its cookies / secure blob.
  Future<void> disposeAssist(int userId) async {
    final key = SessionKey.assist(userId);
    final client = _clients.remove(key.storageId);
    if (client != null) {
      await client.clearSession();
    } else {
      await store.delete(key.secureCookieKey);
    }
  }
}
