import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/automatic_rollcall_answer.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';

RollcallItem item({
  bool expired = false,
  bool answered = false,
  RollcallType type = RollcallType.number,
  String? courseId,
}) => RollcallItem(
  rollcallId: 9,
  courseTitle: '测试课',
  createdByName: '老师',
  type: type,
  status: answered ? 'on_call_fine' : 'absent',
  rollcallStatus: 'on_call',
  isExpired: expired,
  scored: false,
  raw: {'course_id': ?courseId},
);

class Repo extends Fake implements RollcallRepository {
  final calls = <String>[];
  final readOpIds = <String?>[];
  AttendanceCount count = const AttendanceCount(0, 11);
  List<RollcallItem> latest = [item()];
  Object? countError;
  Object? answerError;
  String? answerOpId;
  Completer<String?>? pendingCode;
  void Function()? onCode;
  bool radarOk = true;
  Future<void> Function()? onAttendance;
  double expectedLatitude = 24.5;
  double expectedLongitude = 118.2;
  Future<void> Function()? beforeRadarGuard;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async {
    calls.add('count');
    readOpIds.add(opId);
    await onAttendance?.call();
    if (countError != null) throw countError!;
    return count;
  }

  @override
  Future<List<RollcallItem>> fetchActive({
    CancelToken? cancelToken,
    String? opId,
  }) async {
    calls.add('active');
    readOpIds.add(opId);
    return latest;
  }

  @override
  Future<String?> fetchNumberCode(
    int id, {
    CancelToken? cancelToken,
    String? opId,
  }) async {
    calls.add('code');
    readOpIds.add(opId);
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
    answerOpId = opId;
    if (answerError != null) throw answerError!;
    return const AnswerResult(ok: true);
  }

  @override
  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String? opId,
    Future<void> Function()? beforeSend,
  }) async {
    await beforeRadarGuard?.call();
    await beforeSend?.call();
    expect(latitude, expectedLatitude);
    expect(longitude, expectedLongitude);
    expect(accuracy, 180);
    calls.add('radar');
    if (answerError != null) throw answerError!;
    return AnswerResult(ok: radarOk);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repo repo;
  late AutomaticRollcallAnswer automatic;
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
    automatic = AutomaticRollcallAnswer(
      repository: repo,
      requireCurrent: () async {},
      now: () => now,
    );
  });
  Future<String?> run([MonitorConfig c = percent]) =>
      automatic.process([item()], c, () => current);

  final radar = item(type: RollcallType.radar, courseId: '7');
  CourseRadarPref location({String courseId = '7', bool configured = false}) =>
      CourseRadarPref(
        courseTitle: '测试课',
        courseId: courseId,
        latitude: 24.5,
        longitude: 118.2,
        accuracy: 180,
        userConfigured: configured,
      );
  AutomaticRollcallAnswer withRadar(
    Future<CourseRadarPref?> Function(RollcallItem) read,
  ) => AutomaticRollcallAnswer(
    repository: repo,
    requireCurrent: () async {},
    radarLocation: read,
    now: () => now,
  );

  test('radar requires opt-in and an exact current-course location', () async {
    repo.latest = [radar];
    for (final pref in [null, location(courseId: 'other')]) {
      final handler = withRadar((_) async => pref);
      await handler.process([radar], noWait, () => true);
      expect(repo.calls, isEmpty);
    }
    final handler = withRadar((_) async => location());
    await handler.process([radar], const MonitorConfig(), () => true);
    await handler.process([item(type: RollcallType.radar)], noWait, () => true);
    expect(repo.calls, isEmpty);
  });

  for (final delete in [false, true]) {
    test(
      'saved-place ${delete ? 'deletion' : 'coordinate edit'} during attendance is checked before radar submission',
      () async {
        SharedPreferences.setMockInitialValues({});
        final places = SavedLocationsController();
        final defaults = CourseRadarDefaultsController(userId: 1);
        addTearDown(places.dispose);
        addTearDown(defaults.dispose);
        final place = await places.add(
          note: '教室',
          latitude: 24.5,
          longitude: 118.2,
          accuracy: 180,
        );
        await defaults.configureForCourse(
          courseId: '7',
          courseTitle: '课程',
          selection: RadarGeoSelection(
            latitude: place.latitude,
            longitude: place.longitude,
            accuracy: place.accuracy,
            obtainedVia: RadarObtainedVia.place,
            placeId: place.id,
          ),
        );
        repo.latest = [radar];
        repo.count = const AttendanceCount(11, 11);
        repo.onAttendance = () async {
          if (delete) {
            await places.remove(place.id);
          } else {
            await places.updateCoords(
              place.id,
              latitude: 24.6,
              longitude: 118.3,
            );
            repo.expectedLatitude = 24.6;
            repo.expectedLongitude = 118.3;
          }
        };
        final handler = withRadar(
          (_) => readAutomaticRadarLocation(
            ownerId: 1,
            assistUserId: null,
            courseId: '7',
          ),
        );
        await handler.process([radar], percent, () => current);
        expect(
          repo.calls,
          delete ? ['count', 'active'] : ['count', 'active', 'radar'],
        );
        if (delete) {
          // Configuring a fresh point before any submission lets the next cycle proceed.
          await defaults.configureForCourse(
            courseId: '7',
            courseTitle: '课程',
            selection: const RadarGeoSelection(
              latitude: 24.5,
              longitude: 118.2,
              accuracy: 180,
              obtainedVia: RadarObtainedVia.map,
            ),
          );
          repo.onAttendance = null;
          await handler.process([radar], noWait, () => current);
          expect(repo.calls, ['count', 'active', 'active', 'radar']);
        }
      },
    );
  }

  test(
    'queued radar is blocked after stopping or changing its point; unsent work does not consume the attempt',
    () async {
      repo.latest = [radar];
      var point = location();
      final handler = withRadar((_) async => point);
      repo.beforeRadarGuard = () async {
        current = false;
      };
      await handler.process([radar], noWait, () => current);
      expect(repo.calls, ['active']);
      current = true;
      now = now.add(const Duration(seconds: 61));
      repo.beforeRadarGuard = () async {
        point = const CourseRadarPref(
          courseTitle: '课程',
          courseId: '7',
          latitude: 24.6,
          longitude: 118.3,
          accuracy: 180,
        );
      };
      await handler.process([radar], noWait, () => current);
      expect(repo.calls, ['active', 'active']);
      now = now.add(const Duration(seconds: 61));
      repo.beforeRadarGuard = null;
      repo.expectedLatitude = 24.6;
      repo.expectedLongitude = 118.3;
      await handler.process([radar], noWait, () => current);
      expect(repo.calls, ['active', 'active', 'active', 'radar']);
    },
  );

  test(
    'configured and successful radar positions share attendance rules and preserve accuracy',
    () async {
      repo.latest = [radar];
      for (final configured in [false, true]) {
        repo.calls.clear();
        final handler = withRadar(
          (_) async => location(configured: configured),
        );
        repo.count = const AttendanceCount(3, 11);
        await handler.process([radar], percent, () => true);
        expect(repo.calls, ['count']);
        repo.count = const AttendanceCount(4, 11);
        await handler.process([radar], percent, () => true);
        expect(repo.calls, ['count', 'count', 'active', 'radar']);
        expect(handler.completedIds, contains(9));
      }
    },
  );

  test(
    'removing a radar position or stopping during attendance prevents put',
    () async {
      repo.latest = [radar];
      var present = true;
      final handler = withRadar((_) async => present ? location() : null);
      repo.count = const AttendanceCount(11, 11);
      repo.onAttendance = () async {
        present = false;
      };
      await handler.process([radar], percent, () => current);
      expect(repo.calls, ['count', 'active']);
      repo.calls.clear();
      present = true;
      repo.onAttendance = () async {
        current = false;
      };
      await handler.process([radar], percent, () => current);
      expect(repo.calls, ['count']);
    },
  );

  test(
    'rejected or uncertain radar submissions are never repeated in the run',
    () async {
      repo.latest = [radar];
      for (final failure in [false, true]) {
        repo.calls.clear();
        repo.radarOk = false;
        repo.answerError = failure ? StateError('transport uncertain') : null;
        final handler = withRadar((_) async => location());
        await handler.process([radar], noWait, () => true);
        now = now.add(const Duration(minutes: 2));
        await handler.process([radar], noWait, () => true);
        expect(repo.calls.where((call) => call == 'radar'), hasLength(1));
      }
    },
  );

  test(
    'successful automatic response updates the same engine snapshot',
    () async {
      repo.latest = [radar];
      final handler = withRadar((_) async => location());
      final updates = <MonitorEngineUpdate>[];
      final engine = MonitorEngine(
        config: noWait,
        fetch: () async => [radar],
        notify: (_) async => true,
        processAutomatic: handler.process,
        completedAutomaticIds: () => handler.completedIds,
        onUpdate: updates.add,
      );
      addTearDown(engine.stop);
      engine.start();
      await engine.pollNow();
      expect(
        updates.where((u) => u.items != null).last.items!.single.isAnswered,
        true,
      );
    },
  );

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
    'automatic code reaches signed engine snapshot and Android persisted payload',
    () async {
      final updates = <MonitorEngineUpdate>[];
      final engine = MonitorEngine(
        config: noWait,
        fetch: repo.fetchActive,
        notify: (_) async => true,
        processAutomatic: automatic.process,
        completedAutomaticIds: () => automatic.completedIds,
        automaticNumberCodes: () => automatic.numberCodes,
        onUpdate: updates.add,
      );
      addTearDown(engine.stop);
      engine.start();
      await engine.pollNow();
      var row = updates.where((u) => u.items != null).last.items!.single;
      expect(row.isAnswered, isTrue);
      expect(row.numberCode, 'fresh-code');
      expect(
        RollcallItem.fromJson(row.toMonitorJson()).numberCode,
        'fresh-code',
      );
      repo.latest = [item(answered: true)];
      await engine.pollNow();
      row = updates.where((u) => u.items != null).last.items!.single;
      expect(row.numberCode, 'fresh-code');
      expect(repo.calls.where((v) => v == 'put'), hasLength(1));
    },
  );
  test(
    'automatic diagnostics link decision, submission and feedback without code or credentials',
    () async {
      await AppLog.resetForTest();
      final directory = await Directory.systemTemp.createTemp(
        'xmu_auto_trace_',
      );
      await AppLog.bootstrap(sink: NdjsonFileSink(logsDir: directory));
      addTearDown(() async {
        await AppLog.resetForTest();
        await directory.delete(recursive: true);
      });
      final handler = AutomaticRollcallAnswer(
        repository: repo,
        requireCurrent: () async {},
        runId: 'synthetic-run',
        onAnswered: (row, result) async {
          expect(row.numberCode, 'fresh-code');
        },
      );
      repo.count = const AttendanceCount(11, 11);
      await handler.process([item()], percent, () => true);
      expect(repo.answerOpId, isNotEmpty);
      expect(repo.readOpIds, hasLength(3));
      expect(repo.readOpIds.every((id) => id == repo.answerOpId), isTrue);
      expect(handler.numberCodes[9], 'fresh-code');
      final records = AppLog.index.search(opId: repo.answerOpId);
      expect(
        records.map((r) => r.event),
        containsAll([
          'monitor.auto.start',
          'monitor.auto.code_resolved',
          'monitor.auto.submit',
          'monitor.auto.result',
          'monitor.auto.feedback',
          'monitor.auto.end',
        ]),
      );
      expect(records.every((r) => r.fields['rollcallId'] == 9), isTrue);
      expect(
        records.every((r) => r.fields['runId'] == 'synthetic-run'),
        isTrue,
      );
      expect(
        records.map((r) => r.fields).join(),
        isNot(contains('fresh-code')),
      );
      repo.answerError = DioException(
        requestOptions: RequestOptions(
          path: '/api/rollcall/9/answer_number_rollcall',
          extra: {'requestId': 'synthetic-request'},
        ),
        type: DioExceptionType.receiveTimeout,
      );
      final failed = AutomaticRollcallAnswer(
        repository: repo,
        requireCurrent: () async {},
        runId: 'failed-run',
      );
      await failed.process([item()], noWait, () => true);
      final error = AppLog.index.recent.firstWhere(
        (r) => r.event == 'monitor.auto.error',
      );
      expect(error.fields['stage'], 'submit');
      expect(error.fields['dioType'], 'receiveTimeout');
      expect(error.fields['requestId'], 'synthetic-request');
      expect(error.fields['stack'], isNotEmpty);
      repo.answerError = null;
      final feedbackFailed = AutomaticRollcallAnswer(
        repository: repo,
        requireCurrent: () async {},
        onAnswered: (_, _) async =>
            throw StateError('synthetic feedback failure'),
      );
      final putsBefore = repo.calls.where((v) => v == 'put').length;
      await feedbackFailed.process([item()], noWait, () => true);
      await feedbackFailed.process([item()], noWait, () => true);
      expect(repo.calls.where((v) => v == 'put').length, putsBefore + 1);
      final feedback = AppLog.index.recent.firstWhere(
        (r) => r.event == 'monitor.auto.feedback',
      );
      expect(feedback.level, 'W');
      expect(feedback.fields['ok'], isFalse);
    },
  );
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
