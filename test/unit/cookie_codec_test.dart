import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';

void main() {
  group('CookieCodec', () {
    test('round-trips cookie fields', () {
      final cookies = [
        cookieFromJson({
          'name': 'session',
          'value': 'abc',
          'domain': 'lnt.xmu.edu.cn',
          'path': '/',
          'secure': true,
          'httpOnly': true,
        }),
      ];
      final encoded = encodeCookies(cookies);
      final decoded = decodeCookies(encoded);
      expect(decoded, hasLength(1));
      expect(decoded.single.name, 'session');
      expect(decoded.single.value, 'abc');
      expect(decoded.single.domain, 'lnt.xmu.edu.cn');
      expect(decoded.single.path, '/');
      expect(decoded.single.secure, isTrue);
      expect(decoded.single.httpOnly, isTrue);
    });

    test('decodeCookies returns empty on corrupt json', () {
      expect(decodeCookies('not-json'), isEmpty);
      expect(decodeCookies(''), isEmpty);
    });

    test('parseCookieHeader splits name=value pairs', () {
      final cookies = parseCookieHeader(
        'a=1; b=two; ; broken; =novalue; ok=3',
        domain: 'lnt.xmu.edu.cn',
      );
      expect(cookies.map((c) => c.name).toList(), ['a', 'b', 'ok']);
      expect(cookies.map((c) => c.value).toList(), ['1', 'two', '3']);
      expect(cookies.every((c) => c.domain == 'lnt.xmu.edu.cn'), isTrue);
    });
  });
}
