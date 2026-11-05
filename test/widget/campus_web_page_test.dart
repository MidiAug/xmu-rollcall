import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/browser/browser_environment.dart';
import 'package:xmu_rollcall/features/browser/browser_preferences.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/browser/campus_web_page.dart';
import 'package:xmu_rollcall/features/browser/campus_website.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final width in [640.0, 986.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'website frame fills window, centers title and returns to software $width $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: desktopCaptureTheme(
                (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: TargetPlatform.windows,
                ),
              ),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CampusWebFrame(
                          title: '信息门户：网页标题',
                          onBack: () => Navigator.of(context).pop(),
                          child: const ColoredBox(
                            color: Colors.white,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('打开网页'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开网页'));
          await tester.pumpAndSettle();
          expect(find.byType(AppSidebar), findsNothing);
          expect(find.byType(AppTitleBar), findsOneWidget);
          expect(
            tester.getCenter(find.text('信息门户：网页标题')).dx,
            closeTo(width / 2, .01),
          );
          expect(tester.getSize(find.byType(CampusWebFrame)), Size(width, 720));
          await captureDesktopUi(tester, 'campus-web-frame-$width-$dark');
          await tester.tap(find.byTooltip('返回软件'));
          await tester.pumpAndSettle();
          expect(find.text('打开网页'), findsOneWidget);
          expect(find.byType(CampusWebFrame), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'system browser choice uses external launcher without creating a webview',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        WebsiteOpenModeController.key: WebsiteOpenMode.systemBrowser.name,
      });
      final launched = <Uri>[];
      final url = Uri.parse('https://i.xmu.edu.cn/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websiteExternalLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openCampusWebsite(context, title: '信息门户', url: url),
                child: const Text('门户'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('门户'));
      await tester.pumpAndSettle();
      expect(launched, [url]);
      expect(find.byType(CampusWebPage), findsNothing);
    },
  );

  testWidgets(
    'missing runtime offers retry and external fallback; identity change closes owned page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final current = StateProvider<BrowserIdentity>(
        (ref) => (ownerId: 1, userId: 1, assistId: null),
      );
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(current)),
          browserEnvironmentProvider('owner_1_user_1').overrideWith((
            ref,
          ) async {
            attempts++;
            throw StateError('runtime unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CampusWebPage(
                      title: '门户',
                      url: Uri.parse('https://i.xmu.edu.cn/'),
                    ),
                  ),
                ),
                child: const Text('软件首页'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('软件首页'));
      await tester.pumpAndSettle();
      expect(find.text('系统浏览器打开'), findsOneWidget);
      expect(attempts, 1);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      container.read(current.notifier).state = (
        ownerId: null,
        userId: null,
        assistId: null,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CampusWebPage), findsNothing);
      expect(find.text('软件首页'), findsOneWidget);
    },
  );

  test('web page URLs do not accept executable or local file navigation', () {
    expect(
      isWebPageUrl(
        Uri.parse('https://ids.xmu.edu.cn/authserver/login?service=campus'),
      ),
      isTrue,
    );
    for (final text in [
      'file:///C:/local.txt',
      'javascript:alert(1)',
      'data:text/html,hello',
      'https://name:secret@i.xmu.edu.cn/',
    ]) {
      expect(isWebPageUrl(Uri.parse(text)), isFalse);
    }
  });
}
