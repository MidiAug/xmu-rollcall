import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/features/settings/desktop_notification_settings_page.dart';
import 'package:xmu_rollcall/platform/desktop_notifications.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';

ThemeData _theme({bool dark = false}) {
  final theme = dark ? AppTheme.dark() : AppTheme.light();
  if (Platform.environment['MONITOR_UI_FONT'] == null) return theme;
  ButtonStyle font(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          (style?.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
            fontFamily: 'MonitorUi',
          ),
        ),
      );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'MonitorUi'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'MonitorUi'),
    filledButtonTheme: FilledButtonThemeData(
      style: font(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: font(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(theme.textButtonTheme.style),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: (theme.listTileTheme.titleTextStyle ?? const TextStyle())
          .copyWith(fontFamily: 'MonitorUi'),
    ),
  );
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.chrome, required this.child});
  final DesktopShellChromeController chrome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DesktopShellChromeScope(
      controller: chrome,
      child: Scaffold(
        body: Column(
          children: [
            const AppTitleBar(title: '厦大签到'),
            Container(height: 1, color: p.border),
            Expanded(
              child: Row(
                children: [
                  AppSidebar(
                    current: AppDestination.settings,
                    userLabel: '预览同学',
                    onSelect: (_) {},
                  ),
                  Container(width: 1, color: p.border),
                  Expanded(
                    child: ShellTabDestination(
                      destination: AppDestination.settings,
                      child: Navigator(
                        onGenerateRoute: (_) =>
                            MaterialPageRoute<void>(builder: (_) => child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    final font = Platform.environment['MONITOR_UI_FONT'];
    if (font != null) {
      final bytes = await File(font).readAsBytes();
      await (FontLoader(
        'MonitorUi',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = Platform.environment['MONITOR_UI_ICONS'];
    if (icons != null) {
      final bytes = await File(icons).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0),
    (width: 960.0, dark: true, scale: 1.0),
    (width: 384.0, dark: false, scale: 1.0),
    (width: 320.0, dark: true, scale: 1.3),
  ]) {
    testWidgets('desktop notification test and recovery: $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = Size(
        scenario.width,
        scenario.width >= 600 ? 720 : 844,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      var sends = 0;
      var failSend = false;
      final notifications = DesktopNotifications(
        setup: () async {},
        isForeground: () async => true,
        send: (_, _) async {
          sends++;
          if (sends == 1) await pending.future;
          if (failSend) throw StateError('native show failed');
        },
        showInApp: (_) => false,
      );
      addTearDown(notifications.dispose);
      final chrome = DesktopShellChromeController()
        ..current = AppDestination.settings;
      addTearDown(chrome.dispose);
      final boundary = GlobalKey();
      Future<void> capture(String state) async {
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_MONITOR_UI'] != '1') return;
        await tester.runAsync(() async {
          final directory = await Directory(
            '.tools/notification-polish',
          ).create(recursive: true);
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${directory.path}/${scenario.width.toInt()}-${scenario.dark ? 'dark' : 'light'}-$state.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(dark: scenario.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: scenario.width >= 600
                ? _DesktopFrame(
                    chrome: chrome,
                    child: DesktopNotificationSettingsPage(
                      notifications: notifications,
                    ),
                  )
                : DesktopNotificationSettingsPage(notifications: notifications),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('通知连接'), findsNothing);
      expect(find.text('更多设置与排查'), findsNothing);
      await capture('01-initial');
      await tester.tap(find.text('发送测试'));
      await tester.pump();
      expect(find.text('发送中…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(sends, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('收到刚才的通知了吗？'), findsOneWidget);
      expect(find.text('已确认收到测试通知'), findsNothing);
      await capture('02-sent');
      await tester.tap(find.text('没有收到'));
      await tester.pumpAndSettle();
      expect(find.text('检查 Windows 通知设置'), findsOneWidget);
      await capture('03-help');
      await tester.tap(find.text('已收到'));
      await tester.pumpAndSettle();
      expect(find.text('已确认收到测试通知'), findsOneWidget);
      expect(find.text('检查 Windows 通知设置'), findsNothing);
      await capture('04-confirmed');
      failSend = true;
      await tester.tap(find.text('重新发送'));
      await tester.pumpAndSettle();
      expect(find.text('未能发送通知'), findsOneWidget);
      expect(find.text('已确认收到测试通知'), findsNothing);
      expect(find.text('已收到'), findsNothing);
      await capture('05-failed');
      failSend = false;
      await tester.tap(find.text('发送测试'));
      await tester.pumpAndSettle();
      expect(find.text('收到刚才的通知了吗？'), findsOneWidget);
      expect(find.text('未能发送通知'), findsNothing);
      expect(find.text('检查 Windows 通知设置'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [384.0, 960.0]) {
    testWidgets(
      'Android reminder at $width restores confirmation and invalidates changed permissions',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var status = const AndroidDiscoveryNotificationStatus(
          enabled: true,
          channel: AndroidNotificationChannel(
            'monitor_discovery',
            '发现',
            importance: Importance.high,
            enableVibration: false,
            playSound: true,
          ),
        );
        SharedPreferences.setMockInitialValues({
          'background_reminder_pending_v1': jsonEncode({
            'deadlineMs': DateTime.now()
                .subtract(const Duration(seconds: 1))
                .millisecondsSinceEpoch,
            'fingerprint': status.settingsFingerprint,
          }),
        });
        final boundary = GlobalKey();
        final theme = _theme();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: NotificationSettingsPage(readStatus: () async => status),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('刚才收到提醒了吗？'), findsOneWidget);
        await tester.tap(find.text('已收到提醒'));
        await tester.pumpAndSettle();
        expect(find.text('提醒已实测'), findsOneWidget);
        status = const AndroidDiscoveryNotificationStatus(enabled: false);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('提醒已实测'), findsNothing);
        expect(find.text('允许本应用通知'), findsOneWidget);
        if (Platform.environment['CAPTURE_MONITOR_UI'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '.tools/android-notifications-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
