import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/campus/campus_context_panel.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
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
        'todo truncates both rows without hover hints dark=$dark scale=$scale',
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
          final titleText = title;
          expect(tester.widget<Text>(titleText).maxLines, 1);
          expect(
            tester.widget<Text>(titleText).overflow,
            TextOverflow.ellipsis,
          );
          expect(find.byTooltip('软件工程导论与工程实践（研究生）'), findsNothing);
          expect(find.byTooltip('实验报告：面向对象程序设计与实现，需要完整说明的很长标题'), findsNothing);
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
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(title));
          await tester.pump(const Duration(seconds: 1));
          expect(
            find.descendant(
              of: find.byType(CampusContextView),
              matching: find.byType(Tooltip),
            ),
            findsNothing,
          );
          expect(opens, 0);
          await mouse.removePointer();
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(opens, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'todo card uses neutral hover/press surfaces and preserves layout dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(360, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final palette = dark
            ? AppPalette.darkPalette
            : AppPalette.lightPalette;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: Scaffold(
              backgroundColor: palette.canvas,
              body: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: RepaintBoundary(
                      key: boundary,
                      child: CampusContextView(
                      data: CampusCachedData(
                        schedule: AcademicSchedule(
                          term: '20261',
                          monday: DateTime(2026, 9, 7),
                          fetchedAt: DateTime(2026, 11, 20),
                          rows: const [
                            AcademicCourseRow(
                              courseId: 'c1',
                              courseName: '中国式现代化的理论与实践研究',
                              room: '坤銮楼（2号楼）A206',
                              weekday: 5,
                              firstPeriod: 7,
                              lastPeriod: 8,
                              startMinute: 16 * 60 + 40,
                              endMinute: 18 * 60 + 20,
                              weeks: {11},
                            ),
                            AcademicCourseRow(
                              courseId: 'c2',
                              courseName: '高级人工智能',
                              room: '学武楼（1号楼）C201',
                              weekday: 5,
                              firstPeriod: 9,
                              lastPeriod: 11,
                              startMinute: 19 * 60 + 10,
                              endMinute: 21 * 60 + 45,
                              weeks: {11},
                            ),
                          ],
                        ),
                        homework: [
                          HomeworkItem(
                            id: 1,
                            title: '第四次作业',
                            courseName: '科技论文写作',
                            dueAt: DateTime(2026, 11, 22, 23, 59),
                          ),
                        ],
                      ),
                      now: DateTime(2026, 11, 20, 13, 0),
                      onTimetable: () {},
                      onHomework: () {},
                      onOpenHomework: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
        await tester.pumpAndSettle();

        final surface = find.descendant(
          of: find.byType(CampusContextView),
          matching: find.byType(AppHoverSurface),
        );
        expect(surface, findsOneWidget);
        final cardRect = tester.getRect(surface);
        final panelRect = tester.getRect(find.byKey(boundary));
        final samplePoint = Offset(
          cardRect.right - panelRect.left - 6,
          cardRect.bottom - panelRect.top - 6,
        );

        Future<int> samplePixel([String? captureName]) async =>
            (await tester.runAsync(() async {
              final renderObject =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await renderObject.toImage(pixelRatio: 1);
              try {
                if (captureName != null &&
                    Platform.environment['CAPTURE_TODO_UI'] == '1') {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(
                    'build/todo-ui-review',
                  ).create(recursive: true);
                  await File(
                    'build/todo-ui-review/$captureName.png',
                  ).writeAsBytes(png!.buffer.asUint8List());
                }
                final rgba = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!.buffer.asUint8List();
                final at =
                    (samplePoint.dy.floor() * image.width +
                        samplePoint.dx.floor()) *
                    4;
                return (rgba[at + 3] << 24) |
                    (rgba[at] << 16) |
                    (rgba[at + 1] << 8) |
                    rgba[at + 2];
              } finally {
                image.dispose();
              }
            }))!;

        expect(await samplePixel('todo-panel-idle-$dark'), palette.surface.toARGB32());

        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(cardRect.center);
        await tester.pumpAndSettle();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
        final hovered = await samplePixel('todo-panel-hover-$dark');
        expect(hovered, palette.cardHover.toARGB32());
        expect(hovered, isNot(palette.selected.toARGB32()));

        await mouse.down(cardRect.center);
        await tester.pumpAndSettle();
        expect(await samplePixel(), palette.hover.toARGB32());

        await mouse.up();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(await samplePixel(), palette.surface.toARGB32());
        expect(tester.getRect(surface), cardRect);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
