import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/number_code.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  group('findNumberCode', () {
    test('reads top-level and nested student_rollcalls', () {
      expect(findNumberCode({'number_code': '0042'}), '0042');
      expect(
        findNumberCode({
          'status': 'in_progress',
          'student_rollcalls': [
            {'student_id': 1, 'number_code': '1234'},
          ],
        }),
        '1234',
      );
      expect(
        findNumberCode({
          'data': {'number_code': 7},
        }),
        '7',
      );
      expect(findNumberCode({'student_rollcalls': []}), isNull);
    });
  });

  group('RollcallItem.fromJson', () {
    test(
      'QR type/source aliases work without is_qrcode; unknown stays unknown',
      () {
        for (final hints in [
          {'source': 'qr'},
          {'type': 'qr_rollcall'},
          {'rollcall_type': 'qrcode'},
          {'is_qr': true},
          {'is_qr_code': 1},
          {'type': 'QR-CODE'},
        ]) {
          final item = RollcallItem.fromJson({
            'rollcall_id': 42,
            'is_number': false,
            'is_radar': false,
            ...hints,
          });
          expect(item.type, RollcallType.qrcode, reason: '$hints');
          expect(
            RollcallItem.fromJson(item.toMonitorJson()).type,
            RollcallType.qrcode,
          );
        }
        expect(
          resolveRollcallType({'is_number': false, 'is_radar': false}),
          RollcallType.unknown,
        );
        expect(
          resolveRollcallType({'type': 'future_rollcall'}),
          RollcallType.unknown,
        );
        expect(resolveRollcallType({'source': 'number'}), RollcallType.number);
        expect(
          resolveRollcallType({'type': 'radar_rollcall'}),
          RollcallType.radar,
        );
      },
    );
    test('parses number rollcall', () {
      final item = RollcallItem.fromJson({
        'rollcall_id': 42,
        'course_title': '测试课',
        'created_by_name': '张三',
        'is_number': true,
        'is_radar': false,
        'is_expired': false,
        'status': 'absent',
        'rollcall_status': 'on',
        'scored': false,
      });
      expect(item.rollcallId, 42);
      expect(item.isNumber, isTrue);
      expect(item.typeLabel, '数字');
      expect(item.isAnswered, isFalse);
    });

    test('parses radar and answered', () {
      final item = RollcallItem.fromJson({
        'rollcall_id': 7,
        'course_title': '雷达课',
        'created_by_name': '李四',
        'is_number': false,
        'is_radar': true,
        'is_expired': false,
        'status': 'on_call_fine',
        'rollcall_status': 'on',
        'scored': true,
      });
      expect(item.isRadar, isTrue);
      expect(item.isAnswered, isTrue);
    });

    test('empty list payload shape', () {
      const data = {'rollcalls': <dynamic>[]};
      final raw = data['rollcalls'] as List;
      expect(raw, isEmpty);
    });
  });

  group('MonitorConfig', () {
    test('default interval stays 20s', () {
      const c = MonitorConfig();
      expect(c.effectiveIntervalSeconds, 20);
      expect(MonitorConfig.minIntervalSeconds, 10);
    });

    test('clamps below min', () {
      const c = MonitorConfig(intervalSeconds: 5);
      expect(c.effectiveIntervalSeconds, 10);
    });

    test('normalizes bounds and legacy values to ten-second steps', () {
      for (final entry in {
        10: 10,
        15: 20,
        25: 30,
        120: 120,
        300: 300,
        999: 300,
      }.entries) {
        expect(
          MonitorConfig(intervalSeconds: entry.key).effectiveIntervalSeconds,
          entry.value,
        );
      }
    });

    test('nextDelay respects min and jitter', () {
      final c = const MonitorConfig(intervalSeconds: 20, jitterRatio: 0.2);
      final rand = Random(1);
      for (var i = 0; i < 20; i++) {
        final d = c.nextDelay(rand);
        expect(d.inSeconds, inInclusiveRange(16, 24));
      }
    });

    test(
      'jitter preserves ten-second floor and can extend the base interval',
      () {
        final rand = Random(1);
        const shortest = MonitorConfig(intervalSeconds: 10, jitterRatio: 0.5);
        const longest = MonitorConfig(intervalSeconds: 300, jitterRatio: 0.5);
        final delays = List.generate(
          100,
          (_) => longest.nextDelay(rand).inSeconds,
        );
        expect(delays, everyElement(inInclusiveRange(150, 450)));
        expect(delays.any((seconds) => seconds > 300), isTrue);
        for (var i = 0; i < 100; i++) {
          expect(shortest.nextDelay(rand).inSeconds, inInclusiveRange(10, 15));
        }
      },
    );

    test('classroom preset is not 1Hz', () {
      expect(MonitorPreset.classroom.defaultSeconds, greaterThanOrEqualTo(15));
      expect(MonitorPreset.eco.defaultSeconds, greaterThanOrEqualTo(15));
    });
  });
}
