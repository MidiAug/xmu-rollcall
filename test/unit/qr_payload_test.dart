import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';

void main() {
  group('parseQrRollcallData', () {
    const encoded =
        'https://c-mobile.xmu.edu.cn/j?p=0~%102kgh!3~CLASS_TOKEN!4~%109air';
    test(
      'official encoded payload extracts token and validates base36 ids',
      () {
        expect(
          parseQrRollcallData(
            encoded,
            expectedRollcallId: 433539,
            expectedCourseId: '119825',
          ),
          'CLASS_TOKEN',
        );
        expect(
          parseQrRollcallData('/j?p=0~%102kgh!3~CLASS_TOKEN!4~%109air'),
          'CLASS_TOKEN',
        );
        expect(
          parseQrRollcallData(Uri.encodeComponent(encoded)),
          'CLASS_TOKEN',
        );
      },
    );
    test(
      'rejects wrong event/course, malformed encoded fields and unrelated URLs',
      () {
        expect(
          () => parseQrRollcallData(encoded, expectedRollcallId: 7),
          throwsFormatException,
        );
        expect(
          () => parseQrRollcallData(encoded, expectedCourseId: '7'),
          throwsFormatException,
        );
        for (final raw in [
          'https://lnt.xmu.edu.cn/inclass/courses/119825?m=qr-rollcall/433539',
          '/j?p=0~%102kgh!4~%109air',
          '/j?p=3~a!3~b',
          '{"data":null}',
        ]) {
          expect(() => parseQrRollcallData(raw), throwsFormatException);
        }
      },
    );
    test('JSON and data URL event ids cannot bypass the event check', () {
      expect(
        () => parseQrRollcallData(
          '{"data":"token","rollcallId":8}',
          expectedRollcallId: 7,
        ),
        throwsFormatException,
      );
      expect(
        () => parseQrRollcallData(
          'https://example.org/?data=token&courseId=8',
          expectedCourseId: '7',
        ),
        throwsFormatException,
      );
    });
    test('accepts bare data token', () {
      const raw = 'abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(parseQrRollcallData(raw), raw);
    });

    test('extracts data from json', () {
      expect(
        parseQrRollcallData('{"data":"TOKEN42CHARS______________________XX"}'),
        'TOKEN42CHARS______________________XX',
      );
    });

    test('extracts data query from url', () {
      expect(
        parseQrRollcallData('https://lnt.xmu.edu.cn/qr?data=abc123&x=1'),
        'abc123',
      );
    });

    test('rejects empty', () {
      expect(() => parseQrRollcallData('  '), throwsA(isA<FormatException>()));
    });
  });
}
