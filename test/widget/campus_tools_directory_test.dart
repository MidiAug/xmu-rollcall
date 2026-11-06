import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/campus/campus_calendar_page.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  testWidgets('service entry keyboard activation preserves geometry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: AppServiceTile(
              title: '学年校历',
              description: '学期安排与教学周',
              icon: CupertinoIcons.calendar_today,
              onPressed: () => calls++,
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byType(AppServiceTile));
    final symbol = find.byKey(const ValueKey('service-symbol'));
    final artBefore = tester.getRect(symbol);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.getRect(find.byType(AppServiceTile)), before);
    expect(tester.getRect(symbol), artBefore);
    expect(find.byType(BackdropFilter), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'text link hover and keyboard focus use color without underline $dark',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: desktopCaptureTheme(
              (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: AppTextLink(
                  '校园邮箱',
                  icon: CupertinoIcons.arrow_up_right,
                  onPressed: () => calls++,
                ),
              ),
            ),
          ),
        );
        final label = find.text('校园邮箱');
        final before = tester.getRect(label);
        TextStyle actual() => tester
            .renderObject<RenderParagraph>(
              find.descendant(of: label, matching: find.byType(RichText)),
            )
            .text
            .style!;
        final normal = actual().color;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(label));
        await tester.pumpAndSettle();
        expect(actual().decoration, TextDecoration.none);
        expect(actual().color, isNot(normal));
        expect(tester.getRect(label), before);
        await captureDesktopUi(tester, 'text-link-hover-$dark');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(actual().color, normal);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(actual().decoration, TextDecoration.none);
        expect(actual().color, isNot(normal));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 1);
        await mouse.removePointer();
      },
    );
  }
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  testWidgets('glass chrome becomes opaque without blur at high contrast', (
    tester,
  ) async {
    Widget screen(bool highContrast) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: const Center(
          child: AppGlassSurface(
            child: SizedBox(width: 220, height: 80, child: Text('示例导航')),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pumpWidget(screen(true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('示例导航'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 760.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'directory equal tools and separate graduate section $width $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 840);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: desktopCaptureTheme(
                (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: width == 320
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
              ),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                  ),
                  child: child!,
                ),
              ),
              home: const Scaffold(body: CampusToolsPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppServiceTile), findsNWidgets(5));
          final pageScroll = find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.vertical,
          );
          expect(tester.getRect(pageScroll).right, closeTo(width, .1));
          expect(find.text('常用工具'), findsOneWidget);
          expect(find.text('研究生'), findsOneWidget);
          for (final name in ['信息门户', '教务', '学工', '图书馆', '邮箱']) {
            expect(find.text(name), findsOneWidget);
            final linkFinder = find.ancestor(
              of: find.text(name),
              matching: find.byType(AppTextLink),
            );
            expect(tester.widget<AppTextLink>(linkFinder).icon, isNull);
            expect(
              tester.getCenter(linkFinder).dy,
              tester
                  .getCenter(
                    find.ancestor(
                      of: find.text('信息门户'),
                      matching: find.byType(AppTextLink),
                    ),
                  )
                  .dy,
            );
          }
          for (final name in ['研究生选课', '校外访问', '密码服务']) {
            expect(find.text(name), findsNothing);
          }
          expect(
            tester
                .widget<SingleChildScrollView>(
                  find.byKey(const ValueKey('campus-websites-row')),
                )
                .scrollDirection,
            Axis.horizontal,
          );

          expect(
            tester.getTopLeft(find.text('常用网站')).dy,
            greaterThan(tester.getTopLeft(find.text('研究生')).dy),
          );
          expect(find.text('校园地图、考试安排、成绩计算与助教工具'), findsNothing);
          final map = tester.getSize(
            find.byKey(const ValueKey('tool-campus-map')),
          );
          final exam = tester.getSize(find.byKey(const ValueKey('tool-exams')));
          expect(map, exam);
          if (width >= 760) {
            for (final id in ['gpa', 'calendar']) {
              expect(tester.getSize(find.byKey(ValueKey('tool-$id'))), map);
            }
            final grading = tester.getSize(
              find.byKey(const ValueKey('tool-ta-grading')),
            );
            expect(grading.width, closeTo(map.width * 2 + AppSpace.md, .01));
            expect(grading.height, lessThan(map.height));
          }
          await captureDesktopUi(tester, 'tools-directory-$width-$dark');
          await tester.ensureVisible(find.text('邮箱'));
          await tester.pumpAndSettle();
          await captureDesktopUi(tester, 'tools-websites-$width-$dark');
          await tester.ensureVisible(find.text('学年校历'));
          await tester.tap(find.text('学年校历'));
          await tester.pumpAndSettle();
          expect(find.byType(CampusCalendarPage), findsOneWidget);
          expect(find.text('第一学期'), findsOneWidget);
          expect(find.text('短学期'), findsNWidgets(2));
          await captureDesktopUi(tester, 'calendar-$width-$dark');
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('研究生'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final dark in [false, true]) {
    testWidgets('full directory shell composition dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(1104, 771);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: desktopCaptureTheme(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
          ),
          home: RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: Scaffold(
              body: Column(
                children: [
                  const AppTitleBar(title: '厦大签到'),
                  Expanded(
                    child: Row(
                      children: [
                        AppSidebar(
                          current: AppDestination.campusTools,
                          onSelect: (_) {},
                          userLabel: '示例账号',
                        ),
                        const Expanded(child: CampusToolsPage()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('service-symbol')), findsNWidgets(5));
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/campus_sidebar.png'),
          tester.element(find.byType(AppSidebar)),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.getRect(find.byKey(const ValueKey('tool-campus-map')));
      final grading = tester.getRect(
        find.byKey(const ValueKey('tool-ta-grading')),
      );
      expect(grading.width, closeTo(map.width * 2 + AppSpace.md, .01));
      expect(grading.height, lessThan(map.height));
      expect(grading.bottom, lessThan(771));
      await captureDesktopUi(tester, 'gray-directory-shell-$dark');
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1104.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('calendar dates stay separate at $width scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: desktopCaptureTheme(AppTheme.light()),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: CampusCalendarPage(today: DateTime(2026, 11, 4)),
          ),
        );
        await tester.pumpAndSettle();
        final start = tester.getRect(find.text('2026.09.07'));
        final end = tester.getRect(find.text('2027.01.09'));
        expect(start.overlaps(end), isFalse);
        expect(end.right, lessThanOrEqualTo(width - 16));
        if (width == 320) expect(end.top, greaterThan(start.bottom));
        expect(find.text('当前第 9 周'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
        await captureDesktopUi(tester, 'calendar-dates-$width-$scale');
      });
    }
  }
  testWidgets(
    'calendar month navigation follows published term boundaries and keyboard selection',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: CampusCalendarPage(today: DateTime(2026, 11, 4)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2026年11月'), findsOneWidget);
        String day(int year, int month, int date) => tester
            .getSemantics(
              find.byKey(ValueKey('calendar-day-$year-$month-$date')),
            )
            .label;
        expect(day(2026, 11, 4), contains('第9教学周 今天'));
        final grid = find.byKey(const ValueKey('calendar-month-grid'));
        final gridSize = tester.getSize(grid);
        await tester.tap(find.byKey(const ValueKey('calendar-next')));
        await tester.pumpAndSettle();
        expect(tester.getSize(grid), gridSize);
        expect(day(2026, 12, 31), contains('第17教学周'));
        await tester.tap(find.byKey(const ValueKey('calendar-next')));
        await tester.pumpAndSettle();
        expect(day(2027, 1, 9), contains('第18教学周'));
        expect(day(2027, 1, 10), contains('学期外'));
        expect(
          tester
              .widget<AppIconButton>(
                find.byKey(const ValueKey('calendar-next')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('秋季'));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('2027年2月'), findsOneWidget);
        expect(day(2027, 2, 14), contains('学期外'));
        expect(day(2027, 2, 15), contains('第1教学周'));
        expect(
          tester
              .widget<AppIconButton>(
                find.byKey(const ValueKey('calendar-previous')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'calendar selection retains hover press and arrow cursor dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: desktopCaptureTheme(
              dark ? AppTheme.dark() : AppTheme.light(),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            home: CampusCalendarPage(today: DateTime(2026, 11, 4)),
          ),
        );
        await tester.pumpAndSettle();
        final selected = find.byKey(const ValueKey('calendar-term-row-20261'));
        final other = find.byKey(const ValueKey('calendar-term-row-20262'));
        await tester.ensureVisible(selected);
        final p = AppPalette.of(tester.element(selected));
        Color? fill(Finder row) =>
            (tester
                        .widget<AnimatedContainer>(
                          find.descendant(
                            of: row,
                            matching: find.byType(AnimatedContainer),
                          ),
                        )
                        .decoration!
                    as BoxDecoration)
                .color;
        Future<Color> pixel(Finder row, {Offset? spot}) async {
          final point = spot ?? tester.getTopRight(row) + const Offset(-8, 28);
          return (await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('desktop-ui-capture')),
            );
            final image = await boundary.toImage();
            try {
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              final at =
                  (point.dy.floor() * image.width + point.dx.floor()) * 4;
              return Color.fromARGB(255, data[at], data[at + 1], data[at + 2]);
            } finally {
              image.dispose();
            }
          }))!;
        }

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        final next = find.byKey(const ValueKey('calendar-next'));
        final edge =
            tester.getCenter(next) -
            Offset(tester.getSize(next).width / 2 - .5, 0);
        final idleEdge = await pixel(next, spot: edge);
        await mouse.moveTo(tester.getCenter(next));
        await tester.pumpAndSettle();
        expect(await pixel(next, spot: edge), isNot(idleEdge));
        await mouse.down(tester.getCenter(next));
        await mouse.up();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(
          await pixel(next, spot: edge),
          idleEdge,
          reason:
              'pointer month navigation must not leave a keyboard focus border',
        );
        await mouse.moveTo(tester.getCenter(selected));
        await tester.pumpAndSettle();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
        expect(fill(selected), p.hover);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: selected, matching: find.text('第一学期')),
              )
              .style!
              .color,
          p.dataAccent,
        );
        final selectedPixel = await pixel(selected);
        await mouse.down(tester.getCenter(selected));
        await tester.pumpAndSettle();
        expect(fill(selected), p.controlPressed);
        expect(await pixel(selected), isNot(selectedPixel));
        await mouse.up();
        await tester.pumpAndSettle();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await tester.ensureVisible(other);
        await tester.pumpAndSettle();
        final idlePixel = await pixel(other);
        await mouse.moveTo(tester.getCenter(other));
        await tester.pumpAndSettle();
        expect(fill(other), p.hover);
        expect(await pixel(other), isNot(idlePixel));
        expect(fill(selected), p.surface);
        await captureDesktopUi(tester, 'calendar-hover-$dark');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(fill(other), p.surface);
        await captureDesktopUi(tester, 'calendar-selection-idle-$dark');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final date in [
    DateTime(2026, 11, 4),
    DateTime(2027, 1, 10),
    DateTime(2030, 11, 1),
  ]) {
    testWidgets('calendar boundaries use maintained data $date', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CampusCalendarPage(today: date),
        ),
      );
      await tester.pumpAndSettle();
      if (date.year == 2026) {
        expect(find.text('当前第 9 周'), findsOneWidget);
        await tester.tap(find.byType(AppShellSelect<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
        await tester.pumpAndSettle();
        expect(find.textContaining('2025—2026'), findsOneWidget);
      } else {
        expect(find.textContaining('当前第'), findsNothing);
      }
      if (date.year == 2030) {
        expect(find.textContaining('尚未维护'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
