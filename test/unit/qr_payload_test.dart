import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';

void main() {
  group('parseQrRollcallData', () {
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
        parseQrRollcallData(
          'https://lnt.xmu.edu.cn/qr?data=abc123&x=1',
        ),
        'abc123',
      );
    });

    test('rejects empty', () {
      expect(() => parseQrRollcallData('  '), throwsA(isA<FormatException>()));
    });
  });
}
