import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_NAV_MOTION'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  for (final reduced in [false, true]) {
    testWidgets('mobile highlight travels across tabs, reduced=$reduced', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var current = AppDestination.rollcall;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: StatefulBuilder(
            builder: (context, setState) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  bottomNavigationBar: AppMobileNav(
                    current: current,
                    homeworkCount: 12,
                    onSelect: (value) => setState(() => current = value),
                    onSearch: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final highlight = find.byKey(const ValueKey('mobile-nav-highlight'));
      final initial = tester.getCenter(highlight);
      await tester.tap(find.text('我的'));
      await tester.pump();
      if (!reduced) {
        expect(tester.getCenter(highlight), initial);
        await tester.pump(const Duration(milliseconds: 90));
        final during = tester.getCenter(highlight);
        expect(during.dx, greaterThan(initial.dx));
        expect(during.dx, lessThan(tester.getCenter(find.text('我的')).dx));
        if (Platform.environment['CAPTURE_NAV_MOTION'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/nav-motion').create(recursive: true);
            await File(
              'build/nav-motion/in-flight.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // A second tap redirects the same moving highlight from its current position.
        await tester.tap(find.text('作业'));
        await tester.pump();
        expect(tester.getCenter(highlight).dx, closeTo(during.dx, .01));
      }
      await tester.pumpAndSettle();
      final selected = reduced ? '我的' : '作业';
      expect(
        tester.getCenter(highlight).dx,
        closeTo(tester.getCenter(find.text(selected)).dx, .01),
      );
      expect(
        tester.getSize(highlight).width,
        greaterThan(tester.getSize(highlight).height),
      );
      expect(find.text('12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
