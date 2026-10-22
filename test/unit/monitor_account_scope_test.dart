import 'dart:async';
import 'dart:convert';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'A'),
    );
  }
}

class _Service extends Fake implements AssistService {
  final sessions = <int>[];
  @override
  Future<void> ensureSession(AssistIdentity identity) async {
    sessions.add(identity.userId);
  }
}

class _Repo extends Fake implements RollcallRepository {
  final entered = Completer<void>();
  Completer<String?>? code;
  int puts = 0;
  bool expired = false;
  String courseId = 'a';
  final historyStudents = <int>[];
  int catalogCalls = 0;
  @override
  Future<CourseCatalogSnapshot> fetchCourseCatalog() async {
    catalogCalls++;
    return CourseCatalogSnapshot(
      fetchedAt: DateTime.now(),
      courses: [
        CatalogCourse(
          id: courseId,
          title: courseId,
          timetables: {
            1: [
              TimetableSlot(
                sequence: 1,
                start: DateTime(2000, 1, 3, 8),
                end: DateTime(2000, 1, 3, 9),
              ),
            ],
          },
        ),
        const CatalogCourse(id: 'old', title: '历史课程'),
      ],
    );
  }

  @override
  Future<List<CourseRollcallRecord>> fetchCourseRollcalls({
    required Object courseId,
    required int studentId,
    String courseTitle = '',
  }) async {
    historyStudents.add(studentId);
    return [
      CourseRollcallRecord(
        courseId: '$courseId',
        courseTitle: courseTitle,
        rollcallId: '$studentId-event',
        rollcallTime: DateTime.now(),
        typeLabel: '数字',
        signedStatus: '已签到',
        platformStatus: '',
        detail: '',
      ),
    ];
  }

  @override
  Future<List<RollcallItem>> fetchActive({CancelToken? cancelToken}) async {
    if (!entered.isCompleted) entered.complete();
    if (expired) {
      final request = RequestOptions(path: '/active');
      throw DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
      );
    }
    return [
      RollcallItem.fromJson({
        'rollcall_id': 9,
        'is_number': true,
        'status': 'absent',
      }),
    ];
  }

  @override
  Future<String?> fetchNumberCode(int id, {CancelToken? cancelToken}) async =>
      code?.future ?? '1234';
  @override
  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
    String? opId,
  }) async {
    puts++;
    return const AnswerResult(ok: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Repo a, b;
  late _Service service;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'monitor_auto_answer': true,
      'monitor_answer_wait_mode': 0,
    });
    a = _Repo();
    b = _Repo();
    service = _Service();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        assistServiceProvider.overrideWith((ref) async => service),
        assistControllerProvider.overrideWith(
          (ref) => AssistController(
            ref,
            bootstrap: false,
            initial: const AssistUiState(
              ready: true,
              identities: [
                AssistIdentity(
                  userId: 2,
                  displayName: 'B',
                  kind: AssistCredentialKind.session,
                  deviceId: 'device-b',
                ),
              ],
            ),
          ),
        ),
        rollcallRepositoryProvider.overrideWithValue(a),
        rollcallRepositoryForProvider(2).overrideWithValue(b),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> loaded() async {
    for (var i = 0; i < 100; i++) {
      if (!container.read(monitorControllerProvider).loadingSettings) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('Settings did not finish loading');
  }

  void select(int? id) =>
      container.read(selectedRollcallAccountProvider.notifier).state = id;

  test(
    'accounts restore their own rules without inheriting automatic enablement',
    () async {
      final ctrl = container.read(monitorControllerProvider.notifier);
      await loaded();
      expect(
        container.read(monitorControllerProvider).config.autoAnswer,
        isTrue,
      );
      ctrl.setAnswerWaitMode(AnswerWaitMode.count);
      ctrl.setAnswerWaitValue(23);
      ctrl.setAttendanceIntervalSeconds(45);
      select(2);
      await loaded();
      expect(
        container.read(monitorControllerProvider).config.autoAnswer,
        isFalse,
      );
      ctrl.setAnswerWaitValue(37);
      expect(
        container
            .read(monitorControllerProvider)
            .config
            .effectiveAttendanceIntervalSeconds,
        20,
      );
      ctrl.setAttendanceIntervalSeconds(90);
      select(null);
      await loaded();
      expect(
        container.read(monitorControllerProvider).config.answerWaitCount,
        23,
      );
      expect(
        container
            .read(monitorControllerProvider)
            .config
            .effectiveAttendanceIntervalSeconds,
        45,
      );
      select(2);
      await loaded();
      expect(
        container.read(monitorControllerProvider).config.answerWaitPercent,
        37,
      );
      expect(
        container
            .read(monitorControllerProvider)
            .config
            .effectiveAttendanceIntervalSeconds,
        90,
      );
    },
  );

  test(
    'switch cancels a pending automatic submission and starts the selected repository',
    () async {
      a.code = Completer<String?>();
      final ctrl = container.read(monitorControllerProvider.notifier);
      expect(await ctrl.startAsync(), StartMonitorResult.started);
      await a.entered.future;
      await Future<void>.delayed(Duration.zero);
      select(2);
      expect(container.read(monitorControllerProvider).running, isFalse);
      a.code!.complete('1234');
      expect(await ctrl.startAsync(), StartMonitorResult.started);
      await b.entered.future;
      await Future<void>.delayed(Duration.zero);
      expect(a.puts, 0);
      expect(b.puts, 0);
      expect(service.sessions, [2]);
      expect(container.read(monitorControllerProvider).running, isTrue);
    },
  );

  test('expired imported session stops only that task', () async {
    final ctrl = container.read(monitorControllerProvider.notifier);
    select(2);
    b.expired = true;
    await ctrl.startAsync();
    await b.entered.future;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(monitorControllerProvider).running, isFalse);
    expect(container.read(authControllerProvider).isSignedIn, isTrue);
  });

  test(
    'Android metadata distinguishes credential target from workspace login',
    () {
      final run = AndroidMonitorRun.fromJson(
        const AndroidMonitorRun(
          id: 'b',
          userId: 2,
          ownerUserId: 1,
          assistUserId: 2,
          config: MonitorConfig(autoAnswer: true),
        ).toJson(),
      );
      expect(run.userId, 2);
      expect(run.ownerUserId, 1);
      expect(run.assistUserId, 2);
      final legacy = run.toJson()
        ..remove('ownerUserId')
        ..remove('assistUserId');
      expect(AndroidMonitorRun.fromJson(legacy).ownerUserId, 2);
    },
  );
  test(
    'imported history uses selected timetable courses and its student id',
    () async {
      b.courseId = 'b-only';
      final history = container.read(scopedCourseHistoryProvider(2));
      await container.read(history.notifier).ensureFresh();
      final records = container.read(history).requireValue;
      expect(records.single.courseId, 'b-only');
      expect(records.single.rollcallId, '2-event');
      expect(b.historyStudents, [2]);
      expect(a.catalogCalls, 0);
      expect(service.sessions, [2]);
      select(2);
      expect(
        container
            .read(currentCourseHistoryProvider)
            .requireValue
            .single
            .courseId,
        'b-only',
      );
    },
  );
  test(
    'local histories are isolated and imported accounts cannot claim legacy owner history',
    () async {
      final entry = RollcallHistoryEntry(
        rollcallId: 1,
        courseTitle: 'Legacy',
        typeLabel: '数字',
        ok: true,
        at: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'local_rollcall_history',
        jsonEncode([entry.toJson()]),
      );
      final imported = container.read(localHistoryForProvider(2));
      await container
          .read(imported.notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: 2,
              courseTitle: 'B',
              typeLabel: '数字',
              ok: true,
              at: DateTime.now(),
            ),
          );
      expect(container.read(imported).map((e) => e.rollcallId), [2]);
      await container
          .read(historyProvider.notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: 3,
              courseTitle: 'A',
              typeLabel: '数字',
              ok: true,
              at: DateTime.now(),
            ),
          );
      expect(container.read(historyProvider).map((e) => e.rollcallId), [3, 1]);
      select(2);
      expect(
        container.read(currentLocalHistoryProvider).single.courseTitle,
        'B',
      );
    },
  );
}
