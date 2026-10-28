import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_context_panel.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_TODO_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'todo course precedes clipped title with aligned document dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(300, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opens = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('todo-capture'),
                child: CampusContextView(
                  data: CampusCachedData(
                    homework: [
                      HomeworkItem(
                        id: 1,
                        title: '实验报告：面向对象程序设计与实现，需要完整说明的很长标题',
                        courseName: '软件工程导论',
                        dueAt: DateTime(2026, 10, 29, 23, 59),
                      ),
                    ],
                  ),
                  now: DateTime(2026, 10, 28),
                  onTimetable: () {},
                  onHomework: () => opens++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final course = find.byKey(const ValueKey('todo-course-name'));
        final title = find.byKey(const ValueKey('todo-homework-title'));
        final due = find.text('明天 23:59 截止');
        final mark = find.byKey(const ValueKey('todo-document-mark'));
        expect(
          tester.getTopLeft(course).dy,
          lessThan(tester.getTopLeft(title).dy),
        );
        expect(
          tester.getTopLeft(title).dy,
          lessThan(tester.getTopLeft(due).dy),
        );
        expect(tester.widget<Text>(title).maxLines, 1);
        expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
        expect(
          tester.getRect(mark).top,
          closeTo(tester.getRect(course).top, 3),
        );
        expect(
          tester.getRect(mark).bottom,
          closeTo(tester.getRect(due).bottom, 3),
        );
        expect(
          tester.widget<Icon>(find.byIcon(AppIcons.todoDocument)).size,
          greaterThanOrEqualTo(32),
        );
        if (Platform.environment['CAPTURE_TODO_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('todo-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/todo-ui-review').create(recursive: true);
            await File(
              'build/todo-ui-review/todo-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
