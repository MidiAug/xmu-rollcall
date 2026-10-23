import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';

class _AuthRepository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth({bool signedIn = true}) : super(_AuthRepository()) {
    state = signedIn
        ? const AuthState(
            status: AuthStatus.signedIn,
            profile: UserProfile(id: 1, name: '测试同学'),
          )
        : const AuthState(status: AuthStatus.signedOut);
  }
}

class _Monitor extends MonitorController {
  _Monitor(super.ref);
  void seed(MonitorState value) => state = value;
}

void main() {
  setUpAll(() async {
    final font = Platform.environment['MONITOR_UI_FONT'];
    if (font == null) return;
    await (FontLoader(
      'MonitorSettingsUi',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            Platform.environment['MONITOR_UI_ICONS']!,
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  for (final scenario in [
    (width: 384.0, dark: false, scale: 1.0),
    (width: 960.0, dark: false, scale: 1.0),
    (width: 960.0, dark: true, scale: 1.0),
    (width: 320.0, dark: true, scale: 1.3),
  ]) {
    final width = scenario.width;
    final label = '${width.toInt()}-${scenario.dark ? 'dark' : 'light'}';
    testWidgets(
      'grouped settings, aligned controls and automatic state at $label',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
        );
        addTearDown(container.dispose);
        final boundary = GlobalKey();
        var theme = scenario.dark ? AppTheme.dark() : AppTheme.light();
        if (Platform.environment['MONITOR_UI_FONT'] != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'MonitorSettingsUi'),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.copyWith(
                textStyle: WidgetStatePropertyAll(
                  (theme.textButtonTheme.style?.textStyle?.resolve({}) ??
                          const TextStyle())
                      .copyWith(fontFamily: 'MonitorSettingsUi'),
                ),
              ),
            ),
          );
        }
        Future<void> capture(String state) async {
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_MONITOR_SETTINGS_UI'] != '1') {
            return;
          }
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = await Directory(
              '.tools/monitor-typography',
            ).create(recursive: true);
            await File(
              '${dir.path}/monitor-settings-$label-$state.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: const MonitorSettingsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ctrl = container.read(monitorControllerProvider.notifier);
        const off = '仅提醒，不会自动提交';
        const idle = '已开启，开始检测后生效';
        const active = '发现签到后，按规则自动提交';
        expect(find.text(off), findsOneWidget);
        expect(find.textContaining('雷达使用本课'), findsNothing);
        expect(find.text('最近运行'), findsNothing);
        expect(find.byKey(const ValueKey('monitor-jitter')), findsOneWidget);
        expect(find.byKey(const ValueKey('monitor-interval')), findsOneWidget);
        expect(find.text('更多设置'), findsNothing);
        expect(find.text('签到规则'), findsOneWidget);
        expect(find.text('检测与提醒'), findsOneWidget);
        await capture('off');
        await tester.tap(find.byKey(const ValueKey('monitor-auto-answer')));
        await tester.pumpAndSettle();
        expect(find.text(idle), findsOneWidget);
        expect(find.text(off), findsNothing);
        expect(find.textContaining('雷达使用本课'), findsOneWidget);
        expect(container.read(monitorControllerProvider).running, isFalse);
        final select = tester.getRect(
          find.byType(AppShellSelect<AnswerWaitMode>),
        );
        final threshold = tester.getRect(
          find.byKey(const ValueKey('monitor-answer-control')),
        );
        final attendance = tester.getRect(
          find.byKey(const ValueKey('monitor-attendance-control')),
        );
        expect(select.width, 148);
        expect(threshold.width, 148);
        expect(attendance.width, 148);
        expect(threshold.left, closeTo(select.left, 0.1));
        expect(attendance.right, closeTo(select.right, 0.1));
        await capture('enabled-idle');
        ctrl.debugArmRunning();
        await tester.pumpAndSettle();
        expect(find.text(active), findsOneWidget);
        await capture('enabled-running');
        expect(find.text('人数刷新'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('monitor-jitter')),
        );
        await tester.pumpAndSettle();
        await capture('detection');
        await container
            .read(detectionWindowProvider.notifier)
            .save(const DetectionWindow(enabled: true));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('detection-window-switch')),
        );
        await tester.pumpAndSettle();
        expect(find.text('07:30'), findsOneWidget);
        expect(find.text('22:00'), findsOneWidget);
        await capture('detection-window');
        expect(tester.takeException(), isNull);
        await container
            .read(detectionWindowProvider.notifier)
            .save(const DetectionWindow());
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('monitor-auto-answer')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('monitor-auto-answer')));
        await tester.pumpAndSettle();
        expect(find.text(off), findsOneWidget);
        expect(find.text(active), findsNothing);
        expect(container.read(monitorControllerProvider).running, isTrue);
        expect(
          container.read(monitorControllerProvider).config.autoAnswer,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        ctrl.stop();
      },
    );
  }

  testWidgets(
    'slider pointer, keyboard, bounds and attendance values persist without starting detection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MonitorSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> focusWithTab(Finder target) async {
        final element = target.evaluate().single;
        for (var attempt = 0; attempt < 12; attempt++) {
          final focused = FocusManager.instance.primaryFocus?.context;
          var inside = focused == element;
          focused?.visitAncestorElements((ancestor) {
            if (ancestor == element) inside = true;
            return !inside;
          });
          if (inside) return;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        fail('Slider could not be reached using Tab');
      }

      await tester.ensureVisible(find.byTooltip('增加人数刷新间隔'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('增加人数刷新间隔'));
      await tester.pumpAndSettle();
      final intervalFinder = find.byKey(const ValueKey('monitor-interval'));
      await tester.ensureVisible(intervalFinder);
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(intervalFinder);
      expect(slider.min, 10);
      expect(slider.max, 300);
      expect(slider.divisions, 29);
      Future<void> expectSavedInterval(int seconds) async {
        final restored = ProviderContainer(
          overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
        );
        addTearDown(restored.dispose);
        restored.read(monitorControllerProvider);
        await tester.pumpAndSettle();
        expect(
          restored.read(monitorControllerProvider).config.intervalSeconds,
          seconds,
        );
      }

      var track = tester.getRect(intervalFinder);
      await tester.tapAt(Offset(track.right - 8, track.center.dy));
      await tester.pumpAndSettle();
      expect(
        container.read(monitorControllerProvider).config.intervalSeconds,
        300,
      );
      await expectSavedInterval(300);
      expect(find.text('约 240–360 秒检查一次；连接失败时会延后重试。'), findsOneWidget);
      await tester.tapAt(Offset(track.left + 8, track.center.dy));
      await tester.pumpAndSettle();
      expect(
        container.read(monitorControllerProvider).config.intervalSeconds,
        10,
      );
      await expectSavedInterval(10);
      expect(find.text('约 10–12 秒检查一次；连接失败时会延后重试。'), findsOneWidget);
      await focusWithTab(intervalFinder);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        container.read(monitorControllerProvider).config.intervalSeconds,
        20,
      );
      final jitterFinder = find.byKey(const ValueKey('monitor-jitter'));
      await tester.ensureVisible(jitterFinder);
      await tester.pumpAndSettle();
      track = tester.getRect(jitterFinder);
      await tester.tapAt(Offset(track.left + 8, track.center.dy));
      await tester.pumpAndSettle();
      expect(container.read(monitorControllerProvider).config.jitterRatio, 0);
      await tester.tapAt(Offset(track.right - 8, track.center.dy));
      await tester.pumpAndSettle();
      expect(container.read(monitorControllerProvider).config.jitterRatio, 0.5);
      await focusWithTab(jitterFinder);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final current = container.read(monitorControllerProvider);
      expect(current.config.preset, MonitorPreset.custom);
      expect(current.config.jitterRatio, closeTo(0.45, 0.001));
      expect(current.config.attendanceIntervalSeconds, 25);
      expect(current.config.autoAnswer, isFalse);
      expect(current.running, isFalse);
      final restored = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(restored.dispose);
      restored.read(monitorControllerProvider);
      await tester.pumpAndSettle();
      final saved = restored.read(monitorControllerProvider).config;
      expect(saved.preset, MonitorPreset.custom);
      expect(saved.intervalSeconds, 20);
      expect(saved.jitterRatio, closeTo(0.45, 0.001));
      expect(saved.attendanceIntervalSeconds, 25);
      expect(saved.autoAnswer, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final loading in [true, false]) {
    testWidgets(
      'all edits disabled when ${loading ? 'loading' : 'signed out'}; records expand on demand',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _Auth(signedIn: loading),
            ),
            monitorControllerProvider.overrideWith((ref) => _Monitor(ref)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MonitorSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ctrl =
            container.read(monitorControllerProvider.notifier) as _Monitor;
        ctrl.seed(
          MonitorState(
            config: const MonitorConfig(
              autoAnswer: true,
              preset: MonitorPreset.custom,
            ),
            loadingSettings: loading,
            logs: [
              PollLogEntry(
                at: DateTime(2026, 10, 24, 9, 30),
                ok: true,
                message: '未发现新的签到',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppSwitch>(
                find.byKey(const ValueKey('monitor-auto-answer')),
              )
              .onChanged,
          isNull,
        );
        expect(
          tester
              .widget<Slider>(find.byKey(const ValueKey('monitor-interval')))
              .onChanged,
          isNull,
        );
        expect(
          tester
              .widget<AppShellSelect<AnswerWaitMode>>(
                find.byType(AppShellSelect<AnswerWaitMode>),
              )
              .onChanged,
          isNull,
        );
        for (final button
            in tester
                .widgetList<IconButton>(find.byType(IconButton))
                .where(
                  (button) =>
                      button.tooltip?.startsWith('增加') == true ||
                      button.tooltip?.startsWith('减少') == true,
                )) {
          expect(button.onPressed, isNull);
        }
        expect(
          tester
              .widget<Slider>(find.byKey(const ValueKey('monitor-jitter')))
              .onChanged,
          isNull,
        );
        expect(find.text('未发现新的签到'), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('monitor-logs')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('monitor-logs')));
        await tester.pumpAndSettle();
        expect(find.text('未发现新的签到'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('monitor-logs')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('monitor-logs')));
        await tester.pumpAndSettle();
        expect(find.text('未发现新的签到'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
