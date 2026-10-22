import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/automatic_number_answer.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';

RollcallItem item({
  bool expired = false,
  bool answered = false,
  RollcallType type = RollcallType.number,
}) => RollcallItem(
  rollcallId: 9,
  courseTitle: '测试课',
  createdByName: '老师',
  type: type,
  status: answered ? 'on_call_fine' : 'absent',
  rollcallStatus: 'on_call',
  isExpired: expired,
  scored: false,
);

class Repo extends Fake implements RollcallRepository {
  final calls = <String>[];
  AttendanceCount count = const AttendanceCount(0, 11);
  List<RollcallItem> latest = [item()];
  Object? countError;
  Object? answerError;
  Completer<String?>? pendingCode;
  void Function()? onCode;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id) async {
    calls.add('count');
    if (countError != null) throw countError!;
    return count;
  }

  @override
  Future<List<RollcallItem>> fetchActive({CancelToken? cancelToken}) async {
    calls.add('active');
    return latest;
  }

  @override
  Future<String?> fetchNumberCode(int id, {CancelToken? cancelToken}) async {
    calls.add('code');
    onCode?.call();
    return pendingCode?.future ?? 'fresh-code';
  }

  @override
  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
    String? opId,
  }) async {
    expect(numberCode, 'fresh-code');
    calls.add('put');
    if (answerError != null) throw answerError!;
    return const AnswerResult(ok: true);
  }
}

void main() {
  late Repo repo;
  late AutomaticNumberAnswer automatic;
  late DateTime now;
  var current = true;
  const percent = MonitorConfig(autoAnswer: true, answerWaitPercent: 30);
  const noWait = MonitorConfig(
    autoAnswer: true,
    answerWaitMode: AnswerWaitMode.none,
  );
  setUp(() {
    repo = Repo();
    current = true;
    now = DateTime(2026, 10, 21);
    automatic = AutomaticNumberAnswer(
      repository: repo,
      requireCurrent: () async {},
      now: () => now,
    );
  });
  Future<String?> run([MonitorConfig c = percent]) =>
      automatic.process([item()], c, () => current);

  test(
    'attendance counts only positive rollcall_status; rejects incomplete payloads',
    () {
      final count = AttendanceCount.parse({
        'data': {
          'student_rollcalls': [
            {'rollcall_status': 'on_call_fine', 'status': 'on_call'},
            {
              'rollcall_status': 'absent',
              'status': 'on_call_fine',
              'updated_at': 'now',
            },
          ],
        },
      }, rollcallId: 9);
      expect(count.signed, 1);
      expect(count.total, 2);
      for (final payload in [
        null,
        {},
        {'student_rollcalls': []},
        {
          'student_rollcalls': [
            {'status': 'on_call_fine'},
          ],
        },
        {
          'student_rollcalls': [
            {'rollcall_status': 'on_call_fine'},
          ],
          'total': 2,
        },
        {
          'student_rollcalls': [
            {'rollcall_status': 'on_call_fine', 'rollcall_id': 10},
          ],
        },
      ]) {
        expect(
          () => AttendanceCount.parse(payload, rollcallId: 9),
          throwsFormatException,
        );
      }
    },
  );
  test('disabled automatic answering makes no requests', () async {
    await run(const MonitorConfig());
    expect(repo.calls, isEmpty);
  });
  test(
    'turning automatic answering off invalidates in-flight engine work',
    () async {
      final entered = Completer<void>();
      final gate = Completer<void>();
      var submissions = 0;
      final engine = MonitorEngine(
        config: noWait,
        fetch: () async => [item()],
        notify: (_) async => true,
        onUpdate: (_) {},
        processAutomatic: (_, _, current) async {
          entered.complete();
          await gate.future;
          if (current()) submissions++;
          return null;
        },
      );
      addTearDown(engine.stop);
      engine.start();
      final pending = engine.pollNow();
      await entered.future;
      engine.updateConfig(noWait.copyWith(autoAnswer: false));
      gate.complete();
      await pending;
      expect(submissions, 0);
    },
  );
  test('percentage rounds up, waits, refreshes code, submits once', () async {
    repo.count = const AttendanceCount(3, 11);
    expect(await run(), contains('3/4'));
    expect(repo.calls, ['count']);
    repo.count = const AttendanceCount(4, 11);
    expect(await run(), contains('成功'));
    expect(repo.calls, ['count', 'count', 'active', 'code', 'put']);
    await run();
    expect(repo.calls.where((v) => v == 'put'), hasLength(1));
  });
  test('absolute threshold is not reduced to class size', () async {
    repo.count = const AttendanceCount(2, 2);
    expect(
      await run(
        const MonitorConfig(
          autoAnswer: true,
          answerWaitMode: AnswerWaitMode.count,
          answerWaitCount: 3,
        ),
      ),
      contains('2/3'),
    );
    expect(repo.calls, ['count']);
  });
  test(
    'no-wait mode skips attendance lookup but checks current event',
    () async {
      repo.countError = const FormatException('unavailable');
      await run(noWait);
      expect(repo.calls, ['active', 'code', 'put']);
    },
  );
  test('unavailable attendance never permits a waiting submission', () async {
    repo.countError = const FormatException('unknown');
    await run();
    expect(repo.calls, ['count']);
  });
  test(
    'expired, completed, missing and changed-type events are skipped before put',
    () async {
      for (final rows in <List<RollcallItem>>[
        [],
        [item(expired: true)],
        [item(answered: true)],
        [item(type: RollcallType.qrcode)],
      ]) {
        repo.calls.clear();
        repo.latest = rows;
        await run(noWait);
        expect(repo.calls, ['active']);
      }
    },
  );
  test('cancel while fetching code prevents submission', () async {
    repo.pendingCode = Completer<String?>();
    final pending = run(noWait);
    await Future<void>.delayed(Duration.zero);
    current = false;
    repo.pendingCode!.complete('fresh-code');
    await pending;
    expect(repo.calls, isNot(contains('put')));
  });
  test(
    'timeout after a slow code response returns to monitoring without put',
    () async {
      repo.onCode = () => now = now.add(const Duration(minutes: 5));
      expect(await run(noWait), contains('超时'));
      expect(repo.calls, isNot(contains('put')));
      repo.onCode = null;
      await run(noWait);
      expect(repo.calls.where((v) => v == 'put'), hasLength(1));
    },
  );
  test(
    'uncertain transport result backs off and rechecks server state',
    () async {
      repo.answerError = StateError('connection lost after put');
      await run(noWait);
      await run(noWait);
      expect(repo.calls.where((v) => v == 'put'), hasLength(1));
      now = now.add(const Duration(seconds: 61));
      repo.latest = [item(answered: true)];
      await run(noWait);
      expect(repo.calls.where((v) => v == 'put'), hasLength(1));
    },
  );
  test(
    'unauthorized attendance propagates so engine stops the expired session',
    () async {
      repo.countError = DioException(
        requestOptions: RequestOptions(path: '/student_rollcalls'),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      );
      await expectLater(run(), throwsA(isA<DioException>()));
    },
  );
  test(
    'Android background run preserves automatic strategy and old runs default off',
    () {
      final run = AndroidMonitorRun(
        id: 'r',
        userId: 1,
        config: percent.copyWith(attendanceIntervalSeconds: 45),
      );
      final restored = AndroidMonitorRun.fromJson(run.toJson());
      expect(restored.config.autoAnswer, isTrue);
      expect(restored.config.answerWaitPercent, 30);
      expect(restored.config.effectiveAttendanceIntervalSeconds, 45);
      final legacy = run.toJson()..remove('autoAnswer');
      expect(AndroidMonitorRun.fromJson(legacy).config.autoAnswer, isFalse);
      legacy.remove('attendanceInterval');
      expect(
        AndroidMonitorRun.fromJson(
          legacy,
        ).config.effectiveAttendanceIntervalSeconds,
        20,
      );
    },
  );
}
