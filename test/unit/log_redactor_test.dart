import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

void main() {
  group('LogRedactor', () {
    test('drops sensitive keys and scrubs malicious strings', () {
      final fields = LogRedactor.redactFields({
        'cookie': 'session=abc',
        'password': 'secret',
        'token': 'tok123',
        'ok': true,
        'message':
            'Cookie=session=leak; Authorization: Bearer abc.def; token=xyz '
            'https://lnt.xmu.edu.cn/j?p=QRPAYLOAD&password=pw',
        'numberCode': '1234',
      });

      expect(fields.containsKey('cookie'), isFalse);
      expect(fields.containsKey('password'), isFalse);
      expect(fields.containsKey('token'), isFalse);
      expect(fields['ok'], isTrue);
      expect(fields['numberCode'], '1234');

      final msg = fields['message'] as String;
      expect(msg.toLowerCase(), isNot(contains('session=leak')));
      expect(msg, isNot(contains('Bearer abc')));
      expect(msg.toLowerCase(), isNot(contains('password=pw')));
      expect(msg, contains('[redacted]'));
    });

    test('exceptionFields never uses raw toString with secrets', () {
      final err = Exception(
        'cookie=SESSION_SECRET Authorization: Bearer TOKEN123',
      );
      final fields = LogRedactor.exceptionFields(
        error: err,
        stackTrace: StackTrace.fromString(
          'at foo (https://x?password=pw&token=t)\ncookie=bad',
        ),
        source: 'zone',
      );
      expect(fields['errorType'], contains('Exception'));
      expect(fields['source'], 'zone');
      expect(fields['message'], 'unexpected');
      final stack = fields['stack'] as String;
      expect(stack.toLowerCase(), isNot(contains('session_secret')));
      expect(stack, isNot(contains('TOKEN123')));
      expect(stack.toLowerCase(), isNot(contains('password=pw')));
    });

    test('truncateUtf8 respects byte budget', () {
      // 3-byte UTF-8 chars
      final s = '测' * 1000;
      final out = LogRedactor.truncateUtf8(s, 50);
      expect(utf8.encode(out).length, lessThanOrEqualTo(50));
    });

    test('map summary stays under 2048 UTF-8 bytes', () {
      final big = 'x' * 10000;
      final fields = LogRedactor.redactFields({
        'a': big,
        'b': big,
        'c': big,
      });
      expect(
        utf8.encode(jsonEncode(fields)).length,
        lessThanOrEqualTo(LogRedactor.maxUtf8Bytes),
      );
    });
  });
}
