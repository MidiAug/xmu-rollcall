import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import '../fixtures/preview_fonts.dart';

Future<void> _captureStack(
  WidgetTester tester,
  GlobalKey boundary,
  String name, {
  double density = 1,
}) async {
  if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] != '1') return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: density);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.tools/academic-stacks').create(recursive: true);
    await File(
      '.tools/academic-stacks/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

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
        await _captureStack(
          tester,
          key,
          'even-front-dpr$density',
          density: density,
        );
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
        await _captureStack(
          tester,
          key,
          'odd-front-dpr$density',
          density: density,
        );
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

  testWidgets(
    'touch single and double stacks keep titles, targets and selected details',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 420);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      CatalogCourse course(
        String id,
        String title,
        int first,
        int last,
        int week, {
        int day = 1,
      }) => CatalogCourse(
        id: 'academic:$id',
        title: title,
        instructorNames: ['教师$id'],
        location: '示例教学楼 $id',
        timetables: {
          day: [
            TimetableSlot(
              sequence: first,
              endSequence: last,
              start: DateTime(
                2000,
                1,
                3,
                first == 1 ? 8 : 10,
                first == 1 ? 0 : 10,
              ),
              end: DateTime(
                2000,
                1,
                3,
                last == 1 ? 8 : 11,
                last == 1 ? 45 : 50,
              ),
              dates: {
                TimetableSlot.dateKey(
                  DateTime(2026, 11, 2 + (week - 1) * 7 + day - 1),
                ),
              },
              weekLabel: '第$week周',
            ),
          ],
        },
      );
      const firstTitle = '当前单节课程完整名称与详细实验安排';
      const secondTitle = '后续单节课程完整名称与详细实验安排';
      final courses = [
        course('single-a', firstTitle, 1, 1, 1),
        course('single-b', secondTitle, 1, 1, 2),
        course('double-a', '当前双节课程', 3, 4, 1),
        course('double-b', '后续双节课程', 3, 4, 2),
        course('friday', '星期五末列课程', 1, 1, 1, day: 5),
      ];
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TimetableGridView(
                    courses: courses,
                    referenceDate: DateTime(2026, 11, 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder stack(String period) => find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('stack-1-$period-'),
      );
      final single = stack('1');
      final toggle = find.descendant(
        of: single,
        matching: find.byType(AppIconButton),
      );
      final title = find.descendant(
        of: single,
        matching: find.text(firstTitle),
      );
      expect(tester.getSize(title).width, greaterThan(24));
      expect(tester.getSize(title).height, greaterThan(12));
      final target = tester.getRect(toggle);
      expect(target.size, const Size(44, 44));
      expect(
        tester
            .getRect(single)
            .contains(target.bottomRight - const Offset(1, 1)),
        isTrue,
      );
      await _captureStack(tester, boundary, 'touch-single-double-before');
      // Exercise the newly enlarged bottom edge, not only the icon's center.
      await tester.tapAt(target.bottomRight - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(of: single, matching: find.text(secondTitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stack('3-4'), matching: find.text('当前双节课程')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: single, matching: find.text(secondTitle)),
      );
      await tester.pumpAndSettle();
      expect(find.text('教师single-b'), findsOneWidget);
      expect(find.text('示例教学楼 single-b'), findsWidgets);
      expect(find.text('教师single-a'), findsNothing);
      await tester.tap(find.byTooltip('关闭课程详情'));
      await tester.pumpAndSettle();
      final doubleToggle = find.descendant(
        of: stack('3-4'),
        matching: find.byType(AppIconButton),
      );
      final doubleTarget = tester.getRect(doubleToggle);
      await tester.tapAt(doubleTarget.bottomRight - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: stack('3-4'), matching: find.text('后续双节课程')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: stack('3-4'),
          matching: find.text('示例教学楼 double-b'),
        ),
        findsOneWidget,
      );
      await _captureStack(tester, boundary, 'touch-single-double-after');
      await tester.tap(
        find.descendant(of: stack('3-4'), matching: find.text('后续双节课程')),
      );
      await tester.pumpAndSettle();
      expect(find.text('教师double-b'), findsOneWidget);
      expect(find.text('教师double-a'), findsNothing);
      await tester.tap(find.byTooltip('关闭课程详情'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('timetable-horizontal')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('星期五末列课程').hitTestable(), findsOneWidget);
      await tester.tap(find.text('星期五末列课程'));
      await tester.pumpAndSettle();
      expect(find.text('教师friday'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭课程详情'));
      await tester.pumpAndSettle();
      // Tighten the height until a single period reaches the actual minimum,
      // so the target's lower edge is also tested against its cell's clip.
      tester.view.physicalSize = const Size(320, 240);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('timetable-horizontal')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      final minimumTarget = tester.getRect(toggle);
      expect(tester.getSize(single).height, 44);
      expect(
        tester
            .getSize(
              find.descendant(of: single, matching: find.text(secondTitle)),
            )
            .width,
        greaterThan(24),
      );
      await tester.tapAt(minimumTarget.bottomRight - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: single, matching: find.text(firstTitle)),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      await _captureStack(tester, boundary, 'touch-minimum-height');
      expect(tester.takeException(), isNull);
    },
  );
}
