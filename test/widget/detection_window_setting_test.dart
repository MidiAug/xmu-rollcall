import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final width in [320.0, 384.0, 960.0]) {
    testWidgets(
      'course-derived daily ranges and switch stay reachable at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 720);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: ProviderScope(
              overrides: [
                activeRollcallClockProvider.overrideWithValue(
                  () => DateTime(2026, 10, 28),
                ),
                selectedDetectionWindowProvider.overrideWith(
                  (ref) async => DetectionWindow(
                    scheduleBased: true,
                    enabled:
                        ref.watch(detectionWindowProvider)?.enabled ?? true,
                    intervals: [
                      (
                        start: DateTime(2026, 10, 28, 9, 30),
                        end: DateTime(2026, 10, 28, 12, 20),
                      ),
                      (
                        start: DateTime(2026, 10, 28, 13, 50),
                        end: DateTime(2026, 10, 28, 16, 40),
                      ),
                    ],
                  ),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                home: SubpageScaffold(
                  title: '签到设置',
                  body: AppContentColumn(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SettingsSection(
                          header: '检测与提醒',
                          padTop: false,
                          children: [
                            DetectionWindowSetting(
                              enabled: true,
                              padding: EdgeInsets.all(16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('09:30—12:20、13:50—16:40'), findsOneWidget);
        expect(find.text('07:30'), findsNothing);
        await captureDesktopUi(tester, 'schedule-detection-${width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('detection-window-switch')));
        await tester.pumpAndSettle();
        expect(find.text('全天可自动检测'), findsOneWidget);
        expect((await DetectionWindow.read(reload: true)).enabled, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
