import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/logging/http_log_summary.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

void main() {
  group('HttpLogSummary', () {
    test(
      'number lookup logs UTC query and code availability without roster',
      () {
        final uri = Uri.parse(
          'https://lnt.xmu.edu.cn/api/timetable_rollcalls'
          '?course_ids=42&rollcall_date=2026-10-14&token=secret',
        );
        expect(HttpLogSummary.shouldLog(path: uri.path), isTrue);
        expect(HttpLogSummary.filterQuery(uri), {
          'course_ids': '42',
          'rollcall_date': '2026-10-14',
        });
        expect(HttpLogSummary.shouldLog(path: '/api/rollcall/7'), isTrue);
        final detail = HttpLogSummary.responseSummary({
          'course_id': 42,
          'rollcall_time': '2026-10-14T23:54:31Z',
          'students': [
            {'name': 'private'},
          ],
        }, path: '/api/rollcall/7');
        expect(detail, {
          'course_id': 42,
          'rollcall_time': '2026-10-14T23:54:31Z',
        });
        final summary = HttpLogSummary.responseSummary({
          'rollcalls': [
            {
              'id': 7,
              'number_code': '0042',
              'student_rollcalls': ['private'],
            },
            {'id': 8, 'number_code': null},
          ],
        }, path: uri.path)!;
        expect(summary['items'], [
          {'id': 7, 'hasNumberCode': true},
          {'id': 8, 'hasNumberCode': false},
        ]);
        expect(summary['itemCount'], 2);
        expect(summary.toString(), isNot(contains('private')));
      },
    );

    test('radar list projects type flags and omits inventing [omit]', () {
      final summary = HttpLogSummary.responseSummary({
        'rollcalls': [
          {
            'rollcall_id': 435468,
            'course_title': '测试课',
            'is_number': false,
            'is_radar': false,
            'type': 'qr_rollcall',
            'source': 'qr',
            'status': 'absent',
            'is_expired': false,
          },
        ],
      }, path: '/api/radar/rollcalls');
      expect(summary, isNotNull);
      expect(summary!['itemCount'], 1);
      final item = (summary['items'] as List).first as Map;
      expect(item['rollcallId'], 435468);
      expect(item['type'], 'qr_rollcall');
      expect(item['source'], 'qr');
      expect(item['is_number'], isFalse);
      expect(item.containsKey('is_qrcode'), isFalse);
      final encoded = summary.toString();
      expect(encoded, isNot(contains('[omit]')));
    });

    test('student_rollcalls keeps status and type', () {
      final summary = HttpLogSummary.responseSummary({
        'status': 'in_progress',
        'type': 'qr_rollcall',
        'is_number': false,
        'is_radar': false,
        'number_code': null,
        'student_rollcalls': [
          {'student_id': 1},
        ],
      }, path: '/api/rollcall/435468/student_rollcalls');
      expect(summary!['status'], 'in_progress');
      expect(summary['type'], 'qr_rollcall');
      expect(summary['hasNumberCode'], isFalse);
      expect(summary['studentRollcallCount'], 1);
    });

    test('todos reports topKeys and listKeyHit', () {
      final summary = HttpLogSummary.responseSummary({
        'todo_list': [
          {'id': 978864, 'title': 'hw'},
        ],
      }, path: '/api/todos');
      expect(summary!['listKeyHit'], 'todo_list');
      expect(summary['count'], 1);
      expect(summary['topKeys'], contains('todo_list'));
      expect(summary['sampleIds'], [978864]);
    });

    test('todos empty map without list key', () {
      final summary = HttpLogSummary.responseSummary({
        'unexpected': true,
      }, path: '/api/todos');
      expect(summary!['listKeyHit'], isNull);
      expect(summary['count'], 0);
      expect(summary['topKeys'], ['unexpected']);
    });

    test('shouldLog covers radar and todos without opId', () {
      expect(HttpLogSummary.shouldLog(path: '/api/radar/rollcalls'), isTrue);
      expect(HttpLogSummary.shouldLog(path: '/api/todos'), isTrue);
      expect(HttpLogSummary.shouldLog(path: '/api/profile'), isFalse);
      expect(HttpLogSummary.shouldLog(path: '/api/profile', opId: 'x'), isTrue);
    });
  });

  group('LogRedactor denylist_v1', () {
    test(
      'keeps type/is_number and drops cookie; no qr/data false positive',
      () {
        final fields = LogRedactor.redactFields({
          'type': 'qr_rollcall',
          'is_number': false,
          'payloadSha256Prefix': 'abcdef12',
          'cookie': 'secret',
          'data': 'should_keep_now',
        });
        expect(fields['type'], 'qr_rollcall');
        expect(fields['is_number'], isFalse);
        expect(fields['payloadSha256Prefix'], 'abcdef12');
        expect(fields['data'], 'should_keep_now');
        expect(fields.containsKey('cookie'), isFalse);
      },
    );
  });
}
