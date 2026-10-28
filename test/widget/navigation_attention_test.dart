import '../fixtures/preview_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_NAV_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
    for (final entry in {
      'NavUi': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons':
          'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = File(entry.value);
      if (font.existsSync()) {
        await (FontLoader(
          entry.key,
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  testWidgets(
    'mobile nav retains extra gesture clearance when keyboard opens',
    (tester) async {
      tester.view.physicalSize = const Size(384, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppMobileNav(
              current: AppDestination.rollcall,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.byType(AppMobileNav);
      expect(tester.getSize(nav).height, AppDensity.mobileBar + 22 + 1);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.getSize(nav).height, AppDensity.mobileBar + 22 + 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Settings update hint without resizing desktop=$desktop dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(desktop ? 960 : 320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final hints = ValueNotifier((pending: false, update: false));
          addTearDown(hints.dispose);
          final key = GlobalKey();
          final theme = dark ? AppTheme.dark() : AppTheme.light();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'NavUi'),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(desktop ? 1 : 1.3)),
                  child: child!,
                ),
                home: ValueListenableBuilder(
                  valueListenable: hints,
                  builder: (context, value, _) => Scaffold(
                    body: desktop
                        ? Row(
                            children: [
                              AppSidebar(
                                current: AppDestination.settings,
                                onSelect: (_) {},
                                hasUpdate: value.update,
                                hasPendingPlace: value.pending,
                              ),
                              const Expanded(
                                child: Center(child: Text('课表待完善')),
                              ),
                            ],
                          )
                        : const Center(child: Text('课表待完善')),
                    bottomNavigationBar: desktop
                        ? null
                        : AppMobileNav(
                            current: AppDestination.settings,
                            onSelect: (_) {},
                            hasUpdate: value.update,
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final nav = find.byType(desktop ? AppSidebar : AppMobileNav);
          final initial = tester.getSize(nav);
          final myTab = find.descendant(
            of: nav,
            matching: find.text(desktop ? '设置' : '我的'),
          );
          final position = tester.getRect(myTab);
          final badge = desktop
              ? find.byKey(const ValueKey('desktop-notice-settings'))
              : find.descendant(of: nav, matching: find.byType(Badge));
          hints.value = (pending: false, update: true);
          await tester.pumpAndSettle();
          expect(badge, findsOneWidget);
          expect(find.byTooltip('有上课地点未定位，请在地图上标记'), findsNothing);
          if (desktop) {
            expect(tester.getSize(badge), const Size(7, 7));
            expect(
              tester.getTopLeft(badge).dx,
              greaterThan(tester.getTopRight(myTab).dx),
            );
          } else {
            expect(tester.widget<Badge>(badge).smallSize, 5);
            expect(
              tester.widget<Badge>(badge).backgroundColor,
              AppPalette.of(tester.element(nav)).primary,
            );
          }
          expect(find.byTooltip('有新版本可更新'), findsOneWidget);
          expect(tester.getSize(nav), initial);
          expect(tester.getRect(myTab), position);
          if (Platform.environment['CAPTURE_NAV_UI'] == '1') {
            await tester.runAsync(() async {
              final img =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await img.toByteData(format: ui.ImageByteFormat.png);
              final dir = await Directory(
                'build/desktop-ui-review',
              ).create(recursive: true);
              await File(
                '${dir.path}/nav-${desktop ? 'desktop' : 'mobile'}-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              img.dispose();
            });
          }
          hints.value = (pending: true, update: true);
          await tester.pumpAndSettle();
          if (desktop) {
            final tip = find.byTooltip('有上课地点未定位，请在地图上标记');
            expect(tip, findsOneWidget);
            if (Platform.environment['CAPTURE_NAV_UI'] == '1') {
              final mouse = await tester.createGesture(
                kind: ui.PointerDeviceKind.mouse,
              );
              await mouse.addPointer(location: Offset.zero);
              await mouse.moveTo(tester.getCenter(tip));
              await tester.pump(const Duration(seconds: 1));
              await tester.pumpAndSettle();
              await tester.runAsync(() async {
                final image =
                    await (key.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  'build/desktop-ui-review/place-tooltip-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
              await mouse.removePointer();
              await tester.pumpAndSettle();
            }
            expect(
              tester.getRect(tip).contains(tester.getCenter(find.text('课表'))),
              isTrue,
            );
          }
          expect(badge, findsOneWidget);
          expect(find.byTooltip('有新版本可更新'), findsOneWidget);
          hints.value = (pending: false, update: true);
          await tester.pumpAndSettle();
          expect(badge, findsOneWidget);
          expect(find.byTooltip('有新版本可更新'), findsOneWidget);
          hints.value = (pending: false, update: false);
          await tester.pumpAndSettle();
          expect(badge, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
