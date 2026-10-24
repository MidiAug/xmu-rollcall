import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';
import 'package:xmu_rollcall/features/update/update_download_route_selector.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesktopUiCaptureFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.dismiss);
  test(
    'only built-in mirrors persist; legacy custom nodes fall back before use',
    () async {
      expect(await UpdateDownloadRoute.read(), isNull);
      await UpdateDownloadRoute.save('https://ghproxy.net');
      await (await SharedPreferences.getInstance()).reload();
      expect(
        (await UpdateDownloadRoute.read()).toString(),
        'https://ghproxy.net/',
      );
      for (final invalid in [
        'https://mirror.example/',
        'http://ghproxy.net/',
        'https://user:pass@ghproxy.net/',
        'https://127.0.0.1/',
        'https://localhost/',
        'https://mirror.local/',
        'https://ghproxy.net/payload',
        'https://ghproxy.net/?token=secret',
        'https://ghproxy.net/#fragment',
        'https://ghproxy.net:8443/',
      ]) {
        expect(() => UpdateDownloadRoute.parse(invalid), throwsFormatException);
      }
      await UpdateDownloadRoute.save(null);
      expect(await UpdateDownloadRoute.read(), isNull);
      SharedPreferences.setMockInitialValues({
        UpdateDownloadRoute.key: 'https://mirror.example/',
        'update_download_custom_mirror_v1': 'https://mirror.example/',
      });
      expect(await UpdateDownloadRoute.read(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(UpdateDownloadRoute.key), isFalse);
      expect(prefs.containsKey('update_download_custom_mirror_v1'), isFalse);
      await UpdateDownloadRoute.save('https://gh-proxy.com/');
      expect(
        (await UpdateDownloadRoute.read()).toString(),
        'https://gh-proxy.com/',
      );
    },
  );

  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0),
    (width: 960.0, dark: true, scale: 1.0),
    (width: 384.0, dark: false, scale: 1.0),
    (width: 320.0, dark: true, scale: 1.3),
  ]) {
    testWidgets('preset routes synchronize without custom UI at $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        UpdateDownloadRoute.key: 'https://mirror.example/',
      });
      var changed = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('desktop-ui-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: desktopCaptureTheme(
              scenario.dark ? AppTheme.dark() : AppTheme.light(),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    UpdateDownloadRouteSelector(
                      onChanged: () async {
                        changed++;
                      },
                    ),
                    const UpdateDownloadRouteSelector(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final route = find.byKey(const ValueKey('update-route-select')).first;
      expect(find.text('GitHub 官方'), findsNWidgets(2));
      await tester.tap(route);
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuOption), findsNWidgets(3));
      expect(find.textContaining('自定义'), findsNothing);
      expect(find.text('mirror.example'), findsNothing);
      await captureDesktopUi(
        tester,
        'preset-routes-${scenario.width.toInt()}-${scenario.dark ? 'dark' : 'light'}',
      );
      await tester.tap(find.text('ghproxy.net'));
      await tester.pumpAndSettle();
      expect(find.text('ghproxy.net'), findsNWidgets(2));
      expect(changed, 1);
      expect(
        (await UpdateDownloadRoute.read()).toString(),
        'https://ghproxy.net/',
      );
      await tester.tap(route);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuOption), findsNothing);
      expect(changed, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
