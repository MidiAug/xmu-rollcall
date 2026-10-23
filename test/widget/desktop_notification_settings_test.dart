import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/desktop_notification_settings_page.dart';
import 'package:xmu_rollcall/platform/desktop_notifications.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';

ThemeData _theme() {
  final theme = AppTheme.light();
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
    textButtonTheme: TextButtonThemeData(
      style: font(theme.textButtonTheme.style),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: (theme.listTileTheme.titleTextStyle ?? const TextStyle())
          .copyWith(fontFamily: 'MonitorUi'),
    ),
  );
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
  for (final width in [384.0, 960.0]) {
    testWidgets(
      'notification setup at $width separates send, troubleshoot and confirmation',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final notifications = DesktopNotifications(
          setup: () async {},
          isForeground: () async => true,
          send: (_, _) async {},
          showInApp: (_) => false,
        );
        addTearDown(notifications.dispose);
        final boundary = GlobalKey();
        final theme = _theme();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: DesktopNotificationSettingsPage(
                notifications: notifications,
              ),
            ),
          ),
        );
        await tester.tap(find.text('测试'));
        await tester.pumpAndSettle();
        expect(find.text('刚才收到测试通知了吗？'), findsOneWidget);
        expect(find.text('本次提醒已确认'), findsNothing);
        await tester.tap(find.text('没有收到'));
        await tester.pumpAndSettle();
        expect(find.text('检查系统通知和勿扰模式'), findsOneWidget);
        await tester.tap(find.text('已收到提醒'));
        await tester.pumpAndSettle();
        expect(find.text('本次提醒已确认'), findsOneWidget);
        await tester.tap(find.text('重新测试'));
        await tester.pumpAndSettle();
        expect(find.text('刚才收到测试通知了吗？'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
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
              '.tools/desktop-notifications-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
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
