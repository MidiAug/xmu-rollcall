import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import '../fixtures/preview_fonts.dart';

class _Grades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 28),
    term: '20261',
    records: [],
    education: 'graduate',
  );
}

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final width in [320.0, 384.0]) {
    for (final dark in [false, true]) {
      testWidgets('mobile tools open GPA and return at $width dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [gradeSnapshotProvider.overrideWith(_Grades.new)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.android,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  body: const CampusToolsPage(),
                  bottomNavigationBar: AppMobileNav(
                    current: AppDestination.campusTools,
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('tool-gpa'))).width,
          (width - 44) / 2,
        );
        if (Platform.environment['CAPTURE_MOBILE_STYLE'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/mobile-style-review',
            ).create(recursive: true);
            await File(
              'build/mobile-style-review/tools-$width-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('GPA 计算器'));
        await tester.pumpAndSettle();
        expect(find.byType(GpaPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(CampusToolsPage), findsOneWidget);
        expect(find.byType(GpaPage), findsNothing);
      });
    }
  }
}
