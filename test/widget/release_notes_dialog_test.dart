import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/release_notes_dialog.dart';
import 'package:xmu_rollcall/features/update/update_download_route_selector.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/auxiliary_dialog_capture.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scenario in [
    (width: 960.0, height: 720.0, scale: 1.0, dark: false),
    (width: 960.0, height: 720.0, scale: 1.0, dark: true),
    (width: 320.0, height: 480.0, scale: 1.3, dark: false),
    (width: 320.0, height: 480.0, scale: 1.5, dark: true),
  ]) {
    testWidgets(
      'release notes preserve controls while content scrolls $scenario',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, scenario.height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var downloads = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: scenario.dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: RepaintBoundary(
                key: const ValueKey('dialog-capture'),
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    child: const Text('打开更新说明'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => ReleaseNotesDialog(
                        update: ReleaseUpdate(
                          version: const AppVersion(0, 2, 0, 3),
                          target: UpdateTarget.windows,
                          notes: List.generate(
                            14,
                            (i) => '## 更新 ${i + 1}\n\n改进签到与课表显示，保留既有数据和操作。',
                          ).join('\n\n'),
                          size: 11 * 1024 * 1024,
                          sha256: '0' * 64,
                        ),
                        routeSelector: const UpdateDownloadRouteSelector(),
                        onLink: (_) {},
                        onDownload: () {
                          downloads++;
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开更新说明'));
        await tester.pumpAndSettle();
        final suffix =
            '${scenario.width.toInt()}-${scenario.dark}-${scenario.scale}';
        await captureAuxiliaryDialog(tester, 'release-notes-$suffix');
        expect(find.text('下载'), findsOneWidget);
        final downloadBefore = tester.getRect(find.text('下载'));
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('下载')), downloadBefore);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(ReleaseNotesDialog), findsNothing);
        expect(downloads, 0);
        await tester.tap(find.text('打开更新说明'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('关闭更新说明'));
        await tester.pumpAndSettle();
        expect(downloads, 0);
        expect(find.byType(ReleaseNotesDialog), findsNothing);
        await tester.tap(find.text('打开更新说明'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载'));
        await tester.pumpAndSettle();
        expect(downloads, 1);
        expect(find.byType(ReleaseNotesDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
