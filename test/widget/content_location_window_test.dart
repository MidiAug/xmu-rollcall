import 'package:xmu_rollcall/features/monitor/detection_window_store.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Repo extends Fake implements RollcallRepository {
  int calls = 0;
  @override
  Future<List<RollcallItem>> fetchActiveEnriched({
    CancelToken? cancelToken,
    Map<int, String> cachedNumberCodes = const {},
    bool manual = false,
  }) async {
    calls++;
    return [
      RollcallItem.fromJson({
        'rollcall_id': 1,
        'course_title': '测试课',
        'is_radar': true,
      }),
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.dismiss);

  for (final width in [960.0, 384.0]) {
    testWidgets(
      'toast centers in content region at $width, including root callbacks',
      (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Row(
                children: [
                  if (width == 960) const SizedBox(width: 229),
                  Expanded(child: AppToastRegion(child: Container())),
                ],
              ),
            ),
          ),
        );
        AppToast.show(navigator.currentContext!, '提示');
        await tester.pump();
        expect(
          tester.getCenter(find.text('提示')).dx,
          closeTo(width == 960 ? (229 + width) / 2 : width / 2, .1),
        );
        AppToast.dismiss();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppToast.show(context, '无侧栏'),
                child: const Text('显示'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('显示'));
        await tester.pump();
        expect(tester.getCenter(find.text('无侧栏')).dx, closeTo(width / 2, .1));
        AppToast.dismiss();
      },
    );
  }

  test('daily window handles boundaries, midnight and disabled state', () {
    const window = DetectionWindow(enabled: true);
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);
    expect(window.label, '07:30–22:00');
    expect(window.allows(at(7, 29)), isFalse);
    expect(window.allows(at(7, 30)), isTrue);
    expect(window.allows(at(21, 59)), isTrue);
    expect(window.allows(at(22, 0)), isFalse);
    expect(window.nextStart(at(22, 0)), DateTime(2026, 10, 25, 7, 30));
    const overnight = DetectionWindow(
      enabled: true,
      startMinute: 1320,
      endMinute: 450,
    );
    expect(overnight.allows(at(23, 0)), isTrue);
    expect(overnight.allows(at(2, 0)), isTrue);
    expect(overnight.allows(at(7, 30)), isFalse);
    expect(const DetectionWindow().allows(at(2, 0)), isTrue);
  });

  testWidgets(
    'automatic discovery sleeps to opening time without requests or failures',
    (tester) async {
      final start = tester.binding.clock.now();
      final wall = DateTime(2026, 10, 24, 7, 29);
      var calls = 0;
      final updates = <MonitorEngineUpdate>[];
      final engine = MonitorEngine(
        config: const MonitorConfig(jitterRatio: 0),
        loadDetectionWindow: () async => const DetectionWindow(enabled: true),
        now: () => wall.add(tester.binding.clock.now().difference(start)),
        fetch: () async {
          calls++;
          return [];
        },
        notify: (_) async => true,
        onUpdate: updates.add,
      );
      addTearDown(engine.stop);
      engine.start();
      await engine.pollNow();
      expect(calls, 0);
      expect(updates.last.nextPollAt, DateTime(2026, 10, 24, 7, 30));
      expect(updates.any((update) => update.ok == false), isFalse);
      await tester.pump(const Duration(seconds: 59));
      expect(calls, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      engine.stop();
    },
  );

  testWidgets(
    'automatic entry obeys its policy while manual refresh remains available',
    (tester) async {
      final repo = _Repo();
      var now = DateTime(2026, 10, 24, 7, 29);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          rollcallRepositoryForProvider.overrideWith((ref, id) => repo),
          activeRollcallClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await container.read(detectionWindowProvider.notifier).ready;
      await container
          .read(detectionWindowProvider.notifier)
          .save(const DetectionWindow(enabled: true));
      final provider = activeRollcallsProvider(null);
      container.read(provider);
      await tester.pumpAndSettle();
      expect(container.read(provider).requireValue, isEmpty);
      await container.read(provider.notifier).refresh();
      expect(repo.calls, 1);
      now = DateTime(2026, 10, 24, 7, 30);
      await container.read(provider.notifier).refresh();
      expect(repo.calls, 2);
      expect(container.read(provider).requireValue.single.rollcallId, 1);
      now = DateTime(2026, 10, 24, 22);
      await container.read(provider.notifier).refresh();
      expect(repo.calls, 3);
      expect(container.read(provider).requireValue.single.rollcallId, 1);
      final restored = await DetectionWindowStore.read(reload: true);
      expect(restored.enabled, isTrue);
      expect(restored.label, '课前30分钟至课后30分钟');
    },
  );

  testWidgets('schedule toggle persists without obsolete clock-hour fields', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: DetectionWindowSetting(
              enabled: true,
              padding: EdgeInsets.all(16),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日检测范围'), findsOneWidget);
    expect(find.text('07:30'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('detection-window-switch')));
    await tester.pumpAndSettle();
    expect((await DetectionWindowStore.read(reload: true)).enabled, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'course location picks saved place, then adds map place with note, and persists exact course',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(container.dispose);
      final saved = await container
          .read(savedLocationsProvider.notifier)
          .add(note: '已有教室', latitude: 24.6, longitude: 118.3);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: CourseLocationSetting(courseId: '7', courseTitle: '测试课'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('course-location-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已有教室'));
      await tester.pumpAndSettle();
      var pref = await readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: null,
        courseId: '7',
      );
      expect(pref!.placeId, saved.id);
      expect(
        await readAutomaticRadarLocation(
          ownerId: 2,
          assistUserId: null,
          courseId: '7',
        ),
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('course-location-picker')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('关闭地点选择'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(courseRadarDefaultsProvider.notifier)
            .forCourse(courseId: '7')!
            .placeId,
        saved.id,
      );
      await tester.tap(find.byKey(const ValueKey('course-location-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加地点'));
      await tester.pumpAndSettle();
      expect(find.byType(MapPickPanel), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('保存并使用'));
      await tester.pumpAndSettle();
      expect(find.text('请填写地点备注'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '新教室备注');
      await tester.tap(find.widgetWithText(FilledButton, '保存并使用'));
      await tester.pumpAndSettle();
      expect(find.byType(MapPickPanel), findsNothing);
      expect(find.text('新教室备注'), findsOneWidget);
      pref = await readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: null,
        courseId: '7',
      );
      expect(pref!.labelSnapshot, '新教室备注');
      expect(pref.userConfigured, isTrue);
      expect(container.read(savedLocationsProvider).length, 2);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
    },
  );
}
