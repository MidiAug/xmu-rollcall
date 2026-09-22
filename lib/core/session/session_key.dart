import 'package:xmu_rollcall/core/storage/secure_store.dart';

/// Identifies an HTTP session with its own CookieJar and secure cookie blob.
sealed class SessionKey {
  const SessionKey();

  /// Stable map key for registries.
  String get storageId;

  /// Relative under application-support `cookies/`.
  String get cookieRelativePath;

  /// SecureStore key for the JSON cookie backup.
  String get secureCookieKey;

  bool get isOwner => this is OwnerSessionKey;

  bool get isAssist => this is AssistSessionKey;

  static const SessionKey owner = OwnerSessionKey();

  factory SessionKey.assist(int userId) = AssistSessionKey;

  @override
  bool operator ==(Object other) =>
      other is SessionKey && other.storageId == storageId;

  @override
  int get hashCode => storageId.hashCode;
}

final class OwnerSessionKey extends SessionKey {
  const OwnerSessionKey();

  @override
  String get storageId => 'owner';

  @override
  String get cookieRelativePath => 'owner';

  @override
  String get secureCookieKey => SecureStore.keySessionCookies;
}

final class AssistSessionKey extends SessionKey {
  const AssistSessionKey(this.userId);

  final int userId;

  @override
  String get storageId => 'assist_$userId';

  @override
  String get cookieRelativePath => 'assist/$userId';

  @override
  String get secureCookieKey => 'assist_session_cookies_$userId';
}
