import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

void main() {
  group('SessionKey', () {
    test('owner uses cookies/owner and legacy secure key', () {
      const key = SessionKey.owner;
      expect(key.storageId, 'owner');
      expect(key.cookieRelativePath, 'owner');
      expect(key.secureCookieKey, SecureStore.keySessionCookies);
      expect(key.isOwner, isTrue);
    });

    test('assist isolates path and secure key by userId', () {
      final a = SessionKey.assist(1001);
      final b = SessionKey.assist(1002);
      expect(a.cookieRelativePath, 'assist/1001');
      expect(b.cookieRelativePath, 'assist/1002');
      expect(a.secureCookieKey, 'assist_session_cookies_1001');
      expect(b.secureCookieKey, 'assist_session_cookies_1002');
      expect(a.storageId, isNot(b.storageId));
      expect(a.isOwner, isFalse);
    });

    test('equality by storageId', () {
      expect(SessionKey.assist(7), SessionKey.assist(7));
      expect(SessionKey.assist(7), isNot(SessionKey.assist(8)));
      expect(SessionKey.owner, SessionKey.owner);
    });
  });
}
