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
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'todo has two visual rows with full-text hints dark=$dark scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(300, 500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opens = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('todo-capture'),
                  child: CampusContextView(
                    data: CampusCachedData(
                      homework: [
                        HomeworkItem(
                          id: 1,
                          title: '实验报告：面向对象程序设计与实现，需要完整说明的很长标题',
                          courseName: '软件工程导论与工程实践（研究生）',
                          dueAt: DateTime(2026, 10, 29, 23, 59),
                        ),
                      ],
                    ),
                    now: DateTime(2026, 10, 28),
                    onTimetable: () {},
                    onHomework: () => fail('Item must not open the list'),
                    onOpenHomework: (item) {
                      expect(item.id, 1);
                      opens++;
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final course = find.byKey(const ValueKey('todo-course-name'));
          final title = find.byKey(const ValueKey('todo-homework-title'));
          final due = find.byKey(const ValueKey('todo-deadline'));
          final mark = find.byKey(const ValueKey('todo-document-mark'));
          expect(
            tester.getTopLeft(course).dy,
            lessThan(tester.getTopLeft(title).dy),
          );
          expect(
            tester.getCenter(course).dy,
            closeTo(tester.getCenter(due).dy, 1),
          );
          expect(
            tester.getCenter(mark).dy,
            closeTo(tester.getCenter(title).dy, 1),
          );
          final titleText = find.descendant(
            of: title,
            matching: find.byType(Text),
          );
          expect(tester.widget<Text>(titleText).maxLines, 1);
          expect(
            tester.widget<Text>(titleText).overflow,
            TextOverflow.ellipsis,
          );
          expect(find.byTooltip('软件工程导论与工程实践（研究生）'), findsOneWidget);
          expect(
            find.byTooltip('实验报告：面向对象程序设计与实现，需要完整说明的很长标题'),
            findsOneWidget,
          );
          expect(find.text('明天 23:59'), findsOneWidget);
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
                'build/todo-ui-review/todo-$dark-$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final fullTitle = find.text(
            '实验报告：面向对象程序设计与实现，需要完整说明的很长标题',
            findRichText: true,
          );
          final before = fullTitle.evaluate().length;
          await tester.longPress(title);
          await tester.pumpAndSettle();
          expect(fullTitle.evaluate().length, greaterThan(before));
          expect(opens, 0);
          Tooltip.dismissAllToolTips();
          await tester.pumpAndSettle();
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(opens, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
