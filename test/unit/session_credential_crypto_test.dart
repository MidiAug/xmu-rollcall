import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';

void main() {
  group('SessionCredentialCrypto', () {
    final plain = SessionCredentialPlain(
      cookiesJson: jsonEncode([
        {
          'name': 'session',
          'value': 'tok',
          'domain': 'lnt.xmu.edu.cn',
          'path': '/',
          'secure': true,
          'httpOnly': true,
        },
      ]),
      profileId: 42,
      profileName: '测试同学',
      exportedAt: DateTime.utc(2026, 9, 15, 12),
      suggestedExpiresAt: DateTime.utc(2026, 9, 16, 12),
    );

    test('round-trips with passphrase', () {
      final crypto = SessionCredentialCrypto(
        randomBytes: _fixedBytes(),
        iterations: 1000,
      );
      final sealed = crypto.seal(plain, 'correct-horse');
      expect(sealed, contains('xmu-rollcall-session-v1'));
      final opened = crypto.open(sealed, 'correct-horse');
      expect(opened.profileId, 42);
      expect(opened.profileName, '测试同学');
      expect(opened.cookiesJson, plain.cookiesJson);
      expect(opened.suggestedExpiresAt, plain.suggestedExpiresAt);
    });

    test('wrong passphrase throws', () {
      final crypto = SessionCredentialCrypto(
        randomBytes: _fixedBytes(),
        iterations: 1000,
      );
      final sealed = crypto.seal(plain, 'right');
      expect(
        () => crypto.open(sealed, 'wrong'),
        throwsA(isA<SessionCredentialException>()),
      );
    });

    test('corrupt envelope throws', () {
      final crypto = SessionCredentialCrypto();
      expect(
        () => crypto.open('not-json', 'x'),
        throwsA(isA<SessionCredentialException>()),
      );
    });

    test('expired suggested time is detected', () {
      final expired = SessionCredentialPlain(
        cookiesJson: '[]',
        profileId: 1,
        profileName: 'A',
        exportedAt: DateTime.utc(2026, 1, 1),
        suggestedExpiresAt: DateTime.utc(2026, 1, 2),
      );
      expect(expired.isSuggestedExpired(DateTime.utc(2026, 1, 3)), isTrue);
      expect(expired.isSuggestedExpired(DateTime.utc(2026, 1, 1, 12)), isFalse);
    });
  });
}

BytesFactory _fixedBytes() {
  var n = 0;
  return (int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = (n + i) & 0xff;
    }
    n += length;
    return out;
  };
}
