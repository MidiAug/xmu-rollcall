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

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'course and recurring arrangement exclusions persist, dark=$dark',
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
            ],
          ),
        );
        tester.view.physicalSize = const Size(960, 900);
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
        final monday = find.byKey(const ValueKey('watch-meeting-course/1/1-2'));
        await tester.tap(monday);
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        var scope = CourseWatchScope.fromPrefs(prefs, 9301, 9301);
        expect(scope.allows('course', 1, '1-2'), isFalse);
        expect(scope.allows('course', 5, '1-2'), isTrue);
        final course = find.byKey(const ValueKey('watch-course-course'));
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
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_MONITOR_SETTINGS_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/course-watch-scope').create(recursive: true);
            await File(
              'build/course-watch-scope/${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
