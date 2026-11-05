import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('mobile status inset shares canvas and icon tone dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.android,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 32),
              viewPadding: const EdgeInsets.only(top: 32),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: PageScaffold(
                title: '签到',
                showHeader: false,
                child: Builder(
                  builder: (context) => ColoredBox(
                    key: const ValueKey('page-body'),
                    color: AppPalette.of(context).mobileCanvas,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('page-body'))).dy, 32);
      final overlay = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .value;
      expect(
        overlay.statusBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
      expect(overlay.systemStatusBarContrastEnforced, false);
      expect(overlay.statusBarColor, Colors.transparent);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List();
        List<int> pixel(int x, int y) => pixels.sublist(
          (y * image.width + x) * 4,
          (y * image.width + x) * 4 + 4,
        );
        expect(
          pixel(10, 10),
          pixel(10, 50),
          reason: 'Status inset and page canvas must not form two bands',
        );
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }
}
