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
      expect(findNumberCode({'data': {'number_code': 7}}), '7');
      expect(findNumberCode({'student_rollcalls': []}), isNull);
    });
  });

  group('RollcallItem.fromJson', () {
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
    test('default interval >= 15s', () {
      const c = MonitorConfig();
      expect(c.effectiveIntervalSeconds, greaterThanOrEqualTo(15));
      expect(MonitorConfig.minIntervalSeconds, 15);
    });

    test('clamps below min', () {
      const c = MonitorConfig(intervalSeconds: 5);
      expect(c.effectiveIntervalSeconds, 15);
    });

    test('nextDelay respects min and jitter', () {
      final c = const MonitorConfig(intervalSeconds: 20, jitterRatio: 0.2);
      final rand = Random(1);
      for (var i = 0; i < 20; i++) {
        final d = c.nextDelay(rand);
        expect(d.inSeconds, greaterThanOrEqualTo(15));
        expect(d.inSeconds, lessThanOrEqualTo(30));
      }
    });

    test('classroom preset is not 1Hz', () {
      expect(MonitorPreset.classroom.defaultSeconds, greaterThanOrEqualTo(15));
      expect(MonitorPreset.eco.defaultSeconds, greaterThanOrEqualTo(15));
    });
  });
}
