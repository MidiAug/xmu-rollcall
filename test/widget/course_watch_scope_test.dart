import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';
import 'package:xmu_rollcall/features/monitor/course_watch_courses_page.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final scenario in [
    (false, 960.0),
    (true, 960.0),
    (false, 384.0),
    (true, 384.0),
  ]) {
    final (dark, width) = scenario;
    testWidgets(
      'course and recurring arrangement exclusions persist, dark=$dark width=$width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final slots = [
          TimetableSlot(
            sequence: 1,
            endSequence: 2,
            start: DateTime(2000, 1, 3, 8),
            end: DateTime(2000, 1, 3, 9, 40),
          ),
        ];
        await CourseCatalogStore.write(
          9301,
          CourseCatalogSnapshot(
            fetchedAt: DateTime(2026, 10, 30),
            courses: [
              CatalogCourse(
                id: 'course',
                title: '工程伦理',
                timetables: {1: slots, 5: slots},
              ),
              CatalogCourse(
                id: 'other',
                title: '软件工程实践',
                timetables: {3: slots},
              ),
              const CatalogCourse(id: 'third', title: '示例公共课'),
              const CatalogCourse(id: 'fourth', title: '示例研讨课'),
            ],
          ),
        );
        await AcademicScheduleStore.write(
          9301,
          AcademicSchedule(
            term: '20261',
            monday: DateTime(2026, 9, 7),
            fetchedAt: DateTime(2026, 10, 30),
            rows: [
              for (final day in [1, 5])
                AcademicCourseRow(
                  courseId: 'ethics',
                  courseName: '工程伦理',
                  weekday: day,
                  firstPeriod: 1,
                  lastPeriod: 2,
                  startMinute: 480,
                  endMinute: 580,
                  weeks: {1, 2},
                ),
              const AcademicCourseRow(
                courseId: 'software',
                courseName: '软件工程实践',
                weekday: 3,
                firstPeriod: 1,
                lastPeriod: 2,
                startMinute: 480,
                endMinute: 580,
                weeks: {1, 2},
              ),
              const AcademicCourseRow(courseId: 'third', courseName: '示例公共课'),
              const AcademicCourseRow(courseId: 'fourth', courseName: '示例研讨课'),
            ],
          ),
        );
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: RepaintBoundary(
              key: capture,
              child: const CourseWatchCoursesPage(
                ownerId: 9301,
                targetId: 9301,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Rect card(String id) =>
            tester.getRect(find.byKey(ValueKey('watch-course-card-$id')));
        if (width >= 728) {
          expect(card('course').top, card('other').top);
          expect(card('other').left, greaterThan(card('course').right));
          expect(card('third').top, card('course').bottom + 12);
          expect(card('fourth').top, card('other').bottom + 12);
          expect(card('fourth').top, lessThan(card('third').top));
        } else {
          expect(card('course').left, card('other').left);
          expect(card('other').top, card('course').bottom + 12);
        }
        final monday = find.byKey(const ValueKey('watch-meeting-course/1/1-2'));
        await tester.tap(monday);
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        var scope = CourseWatchScope.fromPrefs(prefs, 9301, 9301);
        expect(scope.allows('course', 1, '1-2'), isFalse);
        expect(scope.allows('course', 5, '1-2'), isTrue);
        final course = find.byKey(const ValueKey('watch-course-course'));
        expect(tester.widget<CheckboxListTile>(course).value, isNull);
        await tester.tap(course);
        await tester.pumpAndSettle();
        scope = CourseWatchScope.fromPrefs(prefs, 9301, 9301);
        expect(scope.allows('course', 5, '1-2'), isFalse);
        expect(scope.allows('other', 3, '1-2'), isTrue);
        expect(
          find.byKey(const ValueKey('watch-meeting-course/5/1-2')),
          findsNothing,
        );
        await tester.tap(course);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(monday).value, isFalse);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('watch-meeting-course/5/1-2')),
              )
              .value,
          isTrue,
        );
        final friday = find.byKey(const ValueKey('watch-meeting-course/5/1-2'));
        await tester.tap(friday);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(course).value, isFalse);
        await tester.tap(course);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(course).value, isTrue);
        expect(tester.widget<CheckboxListTile>(monday).value, isTrue);
        expect(tester.widget<CheckboxListTile>(friday).value, isTrue);
        await tester.tap(monday);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(course).value, isNull);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(
          location: tester.getCenter(find.byType(Checkbox).first),
        );
        await tester.pump(const Duration(milliseconds: 250));
        addTearDown(mouse.removePointer);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_MONITOR_SETTINGS_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(
              'build/course-watch-columns',
            ).create(recursive: true);
            await File(
              'build/course-watch-columns/${width.toInt()}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
