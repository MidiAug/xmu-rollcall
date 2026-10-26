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
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'My tab merges red attention dots without resizing desktop=$desktop dark=$dark',
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
                                hasPendingSchedule: value.pending,
                                hasUpdate: value.update,
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
                            hasPendingSchedule: value.pending,
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
          final myTab = find.descendant(of: nav, matching: find.text('我的'));
          final position = tester.getRect(myTab);
          final badge = find.descendant(of: nav, matching: find.byType(Badge));
          hints.value = (pending: true, update: false);
          await tester.pumpAndSettle();
          expect(badge, findsOneWidget);
          expect(tester.widget<Badge>(badge).smallSize, desktop ? 4 : 5);
          expect(
            tester.widget<Badge>(badge).backgroundColor,
            AppPalette.of(tester.element(nav)).danger,
          );
          expect(find.byTooltip('课表待完善'), findsOneWidget);
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
          expect(badge, findsOneWidget);
          expect(find.byTooltip('课表待完善，有新版本可更新'), findsOneWidget);
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
