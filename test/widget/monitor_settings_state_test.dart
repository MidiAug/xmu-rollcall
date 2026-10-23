import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';

class _AuthRepository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试同学'),
    );
  }
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
  for (final width in [384.0, 960.0]) {
    testWidgets(
      'automatic answer copy follows switch and run state at $width',
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
        var theme = AppTheme.light();
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
              '.tools/notification-polish',
            ).create(recursive: true);
            await File(
              '${dir.path}/monitor-settings-${width.toInt()}-$state.png',
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
                home: const MonitorSettingsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ctrl = container.read(monitorControllerProvider.notifier);
        const off = '仅提醒你处理签到，不会自动提交';
        const idle = '已开启，开始检测后生效';
        const active = '检测到签到后，按下方规则自动提交';
        expect(find.text(off), findsOneWidget);
        expect(find.textContaining('雷达使用本课'), findsNothing);
        await capture('off');
        await tester.tap(find.byType(AppSwitch));
        await tester.pumpAndSettle();
        expect(find.text(idle), findsOneWidget);
        expect(find.text(off), findsNothing);
        expect(find.textContaining('雷达使用本课'), findsOneWidget);
        expect(container.read(monitorControllerProvider).running, isFalse);
        await capture('enabled-idle');
        ctrl.debugArmRunning();
        await tester.pumpAndSettle();
        expect(find.text(active), findsOneWidget);
        await capture('enabled-running');
        await tester.tap(find.byType(AppSwitch));
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
}
