import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
  });
  for (final density in [1.0, 2.0]) {
    testWidgets(
      'term stacks show this week first, rooms and toggle at DPR $density',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = density;
        tester.view.physicalSize = Size(1000 * density, 760 * density);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final data = AcademicSchedule.parse(
          term: '20251',
          monday: DateTime(2025, 9, 15),
          at: DateTime(2025, 9, 23),
          clock: coursePeriodClock(),
          payload:
              jsonDecode(
                    File(
                      'test/fixtures/academic_complex.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TimetableGridView(
                      courses: data.displayOnlyCourses(const []),
                      referenceDate: DateTime(2025, 9, 23),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final stack = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('stack-2-3-4-'),
        );
        expect(stack, findsOneWidget);
        expect(
          find.descendant(of: stack, matching: find.textContaining('101、102')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: stack, matching: find.text('1-16双周')),
          findsOneWidget,
        );
        Future<void> capture(String phase) async {
          if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] != '1') return;
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: density);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('.tools/academic-stacks').create(recursive: true);
            await File(
              '.tools/academic-stacks/$phase-dpr$density.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('even-front');
        await tester.tap(
          find.descendant(of: stack, matching: find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: stack, matching: find.textContaining('205')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: stack, matching: find.text('1-17单周')),
          findsOneWidget,
        );
        await capture('odd-front');
        expect(tester.takeException(), isNull);
        // The toggle is a separate keyboard-focusable action; opening the course still works.
        await tester.tap(
          find.descendant(of: stack, matching: find.text('操作系统示例')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('1-17单周'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
