import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/schedule/schedule_detection.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'course windows merge, show today and ignore retired daily hours',
    () async {
      final day = DateTime(2026, 10, 28);
      await SemesterPreferences.save(2, '20261', DateTime(2026, 10, 26));
      await AcademicScheduleStore.write(
        2,
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 10, 26),
          fetchedAt: day,
          rows: [
            for (final item in [
              ('a', 540, 600),
              ('b', 620, 670),
              ('c', 870, 970),
            ])
              {
                'KCDM': item.$1,
                'BJDM': 'sample',
                'KCMC': '示例',
                'XQ': 3,
                'ZCBH': '1',
                'KSJCDM': item.$1 == 'c'
                    ? 5
                    : item.$1 == 'b'
                    ? 3
                    : 1,
                'JSJCDM': item.$1 == 'c'
                    ? 6
                    : item.$1 == 'b'
                    ? 4
                    : 2,
                'startMinute': item.$2,
                'endMinute': item.$3,
              },
          ],
        ),
      );
      final window = await readScheduleDetectionWindow(2, at: day);
      expect(todayDetectionRanges(window, day), '08:30—11:40、14:00—16:40');
      expect(window.allows(DateTime(2026, 10, 28, 8, 29)), false);
      expect(window.allows(DateTime(2026, 10, 28, 8, 30)), true);
      expect(window.allows(DateTime(2026, 10, 28, 11, 40)), false);
      expect(window.allows(DateTime(2026, 10, 28, 14)), true);
      expect(
        window.nextStart(DateTime(2026, 10, 28, 12)),
        DateTime(2026, 10, 28, 14),
      );
      final unknown = await readScheduleDetectionWindow(3, at: day);
      expect(unknown.allows(day), false);
      expect(todayDetectionRanges(unknown, day), '尚未获取可用课表，可手动检测');
    },
  );
  test(
    'repository enforces automatic bounds but manual requests bypass them',
    () async {
      final store = SecureStore.memory();
      final dio = Dio();
      var requests = 0;
      final repo = RollcallRepository(
        identity: DeviceIdentity(store),
        http: TronHttpClient(
          store: store,
          dio: dio,
          cookieJar: CookieJar(),
          rateLimiter: RateLimiter(
            minInterval: Duration.zero,
            maxPerMinute: 100,
          ),
        ),
        loadDetectionWindow: () async => const DetectionWindow(
          scheduleBased: true,
          enabled: true,
          intervals: [],
        ),
      );
      await repo.http.init();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'rollcalls': []},
              ),
            );
          },
        ),
      );
      await expectLater(
        repo.fetchActive(),
        throwsA(isA<DetectionWindowClosed>()),
      );
      expect(requests, 0);
      expect(await repo.fetchActive(manual: true), isEmpty);
      expect(requests, 1);
    },
  );
  testWidgets(
    'outside course windows automatic discovery sleeps, explicit manual fetch bypasses once',
    (tester) async {
      var automatic = 0, manual = 0;
      final now = DateTime(2026, 10, 28, 8);
      final engine = MonitorEngine(
        config: const MonitorConfig(jitterRatio: 0),
        now: () => now,
        loadDetectionWindow: () async => DetectionWindow(
          scheduleBased: true,
          enabled: true,
          intervals: [
            (
              start: DateTime(2026, 10, 28, 10),
              end: DateTime(2026, 10, 28, 12),
            ),
          ],
        ),
        fetch: () async {
          automatic++;
          return [];
        },
        manualFetch: () async {
          manual++;
          return [];
        },
        notify: (_) async => true,
        onUpdate: (_) {},
      );
      addTearDown(engine.stop);
      engine.start();
      await engine.pollNow();
      expect(automatic, 0);
      await engine.pollNow(manual: true);
      expect(manual, 1);
      await engine.pollNow();
      expect(automatic, 0);
      engine.stop();
    },
  );
}
