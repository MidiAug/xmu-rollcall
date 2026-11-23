import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';

import '../fixtures/preview_fonts.dart';
import '../fixtures/homework_preview.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('README homework preview desktop=$desktop dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = desktop
            ? const Size(1120, 780)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        if (!desktop) {
          tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          HomeworkPreviewScope(
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: desktop
                      ? TargetPlatform.windows
                      : TargetPlatform.android,
                ),
                home: Scaffold(
                  body: const HomeworkHubPage(),
                  bottomNavigationBar: desktop
                      ? null
                      : AppMobileNav(
                          current: AppDestination.homework,
                          onSelect: (_) {},
                          onSearch: () {},
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('实验二：分类模型与评估'), findsOneWidget);
        if (!desktop) {
          expect(
            tester.getTopLeft(find.text('全部 3')).dy,
            greaterThanOrEqualTo(28),
          );
        }
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_README'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: desktop ? 1 : 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = await Directory(
              'build/readme-preview',
            ).create(recursive: true);
            await File(
              '${directory.path}/${desktop ? 'windows' : 'android'}-homework${dark ? '-dark' : ''}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
