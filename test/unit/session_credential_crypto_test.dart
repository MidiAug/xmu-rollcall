import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';

void main() {
  group('AssistTokenCodec', () {
    final session = AssistPackagePlain(
      kind: AssistCredentialKind.session,
      deviceId: 'dev-1',
      profileId: 42,
      profileName: '测试同学',
      exportedAt: DateTime.utc(2026, 9, 15, 12),
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
    );

    final account = AssistPackagePlain(
      kind: AssistCredentialKind.account,
      deviceId: 'dev-2',
      profileId: 7,
      profileName: '账密同学',
      exportedAt: DateTime.utc(2026, 9, 15, 12),
      username: '3180000000',
      password: 'secret',
    );

    test('round-trips session package as xmu2 line', () {
      final codec = AssistTokenCodec(randomBytes: _fixedBytes());
      final sealed = codec.seal(session);
      expect(sealed.startsWith('xmu2.'), isTrue);
      expect(sealed.contains('\n'), isFalse);
      final opened = codec.open(sealed);
      expect(opened.kind, AssistCredentialKind.session);
      expect(opened.profileId, 42);
      expect(opened.deviceId, 'dev-1');
      expect(opened.cookiesJson, session.cookiesJson);
    });

    test('round-trips account package', () {
      final codec = AssistTokenCodec(randomBytes: _fixedBytes());
      final sealed = codec.seal(account);
      final opened = codec.open(sealed);
      expect(opened.kind, AssistCredentialKind.account);
      expect(opened.username, '3180000000');
      expect(opened.password, 'secret');
      expect(opened.deviceId, 'dev-2');
    });

    test('corrupt token throws', () {
      final codec = AssistTokenCodec();
      expect(
        () => codec.open('not-a-token'),
        throwsA(isA<SessionCredentialException>()),
      );
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
