import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import '../fixtures/preview_fonts.dart';

class Repo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class Grades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 28, 10),
    term: '20261',
    records: [
      GradeRecord({
        'WID': 'a',
        'KCM': '程序设计基础',
        'XNXQDM': '2026-2027-1',
        'XF': 2,
        'JDF': 4,
        'ZCJ': 95,
      }),
      GradeRecord({
        'WID': 'b',
        'KCLBDM_DISPLAY': '通识教育课程',
        'KCM': '课程名称很长的另一门测试课程用于检查边界',
        'XNXQDM': '2025-2026-2',
        'XF': 1,
        'JDF': 2,
        'ZCJ': 75,
      }),
    ],
  );
}

class GraduateEmptyGrades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 28),
    term: '20261',
    records: [],
    education: 'graduate',
  );
}

class FourYearGrades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 31, 0, 11),
    term: '20261',
    records: [
      for (var year = 2026; year >= 2023; year--)
        GradeRecord({
          'WID': 'academic-course-$year',
          'KCM': year == 2026 ? '新时代中国特色社会主义劳动教育' : '学年课程$year',
          'XNXQDM': '$year-${year + 1}-1',
          'XF': 2,
          'JDF': year == 2026 ? 'N/A' : 4,
          'ZCJ': year == 2026 ? 'P' : 95,
          if (year == 2026) 'XSZCJMC': '合格',
        }),
    ],
  );
}

class ManyGrades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 28),
    term: '20261',
    records: [
      for (var term = 0; term < 6; term++)
        for (var course = 0; course < 8; course++)
          GradeRecord({
            'WID': '$term-$course',
            'KCM': course == 5
                ? '跨学科课程名称很长时也必须保持单行截断并且能够通过悬停查看完整课程名称'
                : '学期${term + 1}课程${course + 1}',
            'XNXQDM':
                '${2026 - (term + 1) ~/ 2}-${2027 - (term + 1) ~/ 2}-${term.isEven ? 1 : 2}',
            'XF': course % 3 + 1,
            'JDF': course == 7
                ? 'N/A'
                : course == 0
                ? 0
                : 4 - (course % 3) * .5,
            'ZCJ': course == 0 ? 50 : 95 - course,
          }),
      GradeRecord({
        'WID': 'legacy',
        'KCM': '未识别学期的课程',
        'XNXQDM': 'legacy',
        'XF': 1,
        'JDF': 3,
        'ZCJ': 80,
      }),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final file = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'GPA groups four-year filters and update metadata $width $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => Auth()),
                gradeSnapshotProvider.overrideWith(FourYearGrades.new),
              ],
              child: MaterialApp(
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: width < 600
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width < 600 ? 1.5 : 1),
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(key: capture, child: const GpaPage()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('学年'));
          await tester.pumpAndSettle();
          final calculation = find.byKey(const ValueKey('grade-calculation'));
          final updated = find.byKey(const ValueKey('grade-updated-at'));
          expect(
            find.descendant(of: calculation, matching: updated),
            findsOneWidget,
          );
          expect(find.text('成绩更新于 2026-10-31 00:11'), findsOneWidget);
          expect(find.text('已选 0 门 / 可计 0 门'), findsOneWidget);
          for (final label in ['总绩点', '学年', '近学期', '学期']) {
            expect(
              tester
                  .renderObject<RenderParagraph>(find.text(label))
                  .didExceedMaxLines,
              isFalse,
              reason: 'range labels must remain complete at large text sizes',
            );
          }
          if (width >= 960) {
            final firstYear = tester.getTopLeft(
              find.byKey(const ValueKey('grade-year-2026')),
            );
            final lastYear = tester.getTopLeft(
              find.byKey(const ValueKey('grade-year-2023')),
            );
            expect(lastYear.dy, firstYear.dy);
            final heading = tester.getRect(
              find.byKey(const ValueKey('grade-course-heading')),
            );
            expect(
              heading.top - tester.getRect(calculation).bottom,
              closeTo(24, .1),
            );
            expect(
              tester
                      .getRect(
                        find.byKey(
                          const ValueKey('grade-term-group-2026-2027-1'),
                        ),
                      )
                      .top -
                  heading.bottom,
              closeTo(12, .1),
            );
          }
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_GPA_UI'] == '1') {
            await tester.runAsync(() async {
              final im =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await im.toByteData(format: ui.ImageByteFormat.png);
              await Directory('build/gpa-ui-review').create(recursive: true);
              await File(
                'build/gpa-ui-review/gpa-four-years-$width-$dark.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              im.dispose();
            });
          }
          Focus.of(tester.element(find.text('学年'))).requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('grade-recent')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'GPA handles six semesters, zero points, N/A and an unknown semester',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => Auth()),
            gradeSnapshotProvider.overrideWith(ManyGrades.new),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const GpaPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('学期 GPA'), findsOneWidget);
      expect(find.text('26秋'), findsOneWidget);
      expect(find.text('24春'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('grade-legacy')),
        500,
      );
      expect(find.text('未识别学期的课程'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'recent count adjusts in place with bounds, feedback and keyboard dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => Auth()),
              gradeSnapshotProvider.overrideWith(ManyGrades.new),
            ],
            child: MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: RepaintBoundary(key: capture, child: const GpaPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('近学期'));
        await tester.pumpAndSettle();
        final more = find.byKey(const ValueKey('grade-recent-more'));
        final less = find.byKey(const ValueKey('grade-recent-less'));
        String count() => tester
            .widget<Text>(find.byKey(const ValueKey('grade-recent-value')))
            .data!;
        VoidCallback? action(Finder control) => tester
            .widget<IconButton>(
              find.descendant(of: control, matching: find.byType(IconButton)),
            )
            .onPressed;
        final point = tester.getTopLeft(more) + const Offset(8, 8);
        Future<Color> pixel() async => (await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(255, data[at], data[at + 1], data[at + 2]);
          } finally {
            image.dispose();
          }
        }))!;
        expect(count(), '2');
        final idle = await pixel();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        await mouse.moveTo(point);
        await tester.pumpAndSettle();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
        final hover = await pixel();
        expect(hover, isNot(idle));
        await mouse.down(point);
        await tester.pumpAndSettle();
        expect(count(), '2');
        expect(await pixel(), isNot(hover));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(count(), '3');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(await pixel(), idle);
        for (var i = 0; i < 4; i++) {
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        expect(count(), '7');
        expect(action(more), isNull);
        for (var i = 0; i < 6; i++) {
          await tester.tap(less);
          await tester.pumpAndSettle();
        }
        expect(count(), '1');
        expect(action(less), isNull);
        Focus.of(
          tester.element(
            find.descendant(of: more, matching: find.byType(Icon)),
          ),
        ).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(count(), '2');
        expect(find.text('最近 2 个有成绩的学期'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'GPA course keeps quiet fill and the checkbox owns feedback dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(960, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => Auth()),
              gradeSnapshotProvider.overrideWith(Grades.new),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: RepaintBoundary(key: capture, child: const GpaPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('grade-b'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final point = tester.getTopRight(row) + const Offset(-4, 5);
        Future<Color> pixel() async => (await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(255, data[at], data[at + 1], data[at + 2]);
          } finally {
            image.dispose();
          }
        }))!;
        final idle = await pixel();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        await mouse.moveTo(point);
        await tester.pumpAndSettle();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
        expect(await pixel(), idle);
        final checkbox = find.descendant(
          of: row,
          matching: find.byType(AppCheckbox),
        );
        expect(tester.widget<AppCheckbox>(checkbox).value, isTrue);
        await mouse.down(point);
        await tester.pumpAndSettle();
        expect(tester.widget<AppCheckbox>(checkbox).value, isTrue);
        expect(await pixel(), idle);
        await mouse.cancel();
        await tester.pumpAndSettle();
        expect(tester.widget<AppCheckbox>(checkbox).value, isTrue);
        await mouse.down(point);
        await mouse.up();
        await tester.pumpAndSettle();
        expect(tester.widget<AppCheckbox>(checkbox).value, isFalse);
        expect(find.text('4.00'), findsOneWidget);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(await pixel(), idle);
        final p = AppPalette.of(tester.element(row));
        final light = p.dataAccent.computeLuminance(),
            darkSurface = p.surface.computeLuminance();
        final contrast = light > darkSurface
            ? (light + .05) / (darkSurface + .05)
            : (darkSurface + .05) / (light + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'graduate unpublished grades are a normal empty state with separate rules',
    (tester) async {
      tester.view.physicalSize = const Size(960, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => Auth()),
            gradeSnapshotProvider.overrideWith(GraduateEmptyGrades.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: RepaintBoundary(key: captureKey, child: const GpaPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('教务查询成功，暂未发布成绩；出分后可手动刷新'), findsOneWidget);
      expect(find.text('暂时无法读取成绩'), findsNothing);
      await tester.tap(find.text('学年'));
      await tester.pumpAndSettle();
      expect(find.text('成绩发布后显示可选学年'), findsOneWidget);
      expect(find.text('教务查询成功，暂未发布成绩；出分后可手动刷新'), findsOneWidget);
      await tester.tap(find.text('总绩点'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('计算规则与来源'));
      await tester.tap(find.text('计算规则与来源'));
      await tester.pumpAndSettle();
      expect(find.text('本科生成绩管理办法'), findsNothing);
      expect(find.text('研究生成绩管理文件'), findsOneWidget);
      if (Platform.environment['CAPTURE_GPA_UI'] == '1') {
        await tester.runAsync(() async {
          final render =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final im = await render.toImage();
          final data = await im.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/gpa-ui-review').create(recursive: true);
          await File(
            'build/gpa-ui-review/graduate-empty.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          im.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('GPA receipt stays readable with large text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => Auth()),
          gradeSnapshotProvider.overrideWith(Grades.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const GpaPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3.33'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('grade-b')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('grade-b')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('grade-summary')));
    expect(find.text('4.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 384.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'GPA layout, selection and cached metadata at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => Auth()),
                gradeSnapshotProvider.overrideWith(Grades.new),
              ],
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                    platform: width < 600
                        ? TargetPlatform.android
                        : TargetPlatform.windows,
                  ),
                  home: const GpaPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          expect(find.textContaining('2026-10-28 10:00'), findsOneWidget);
          expect(tester.takeException(), isNull);
          Future<void> capture(String name) async {
            if (Platform.environment['CAPTURE_GPA_UI'] != '1') return;
            await tester.runAsync(() async {
              final render =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final im = await render.toImage();
              final data = await im.toByteData(format: ui.ImageByteFormat.png);
              await Directory('build/gpa-ui-review').create(recursive: true);
              await File(
                'build/gpa-ui-review/$name-$width-$dark.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              im.dispose();
            });
          }

          await capture('gpa');
          await tester.ensureVisible(find.byKey(const ValueKey('grade-b')));
          await tester.tap(find.byKey(const ValueKey('grade-b')));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('grade-b')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('grade-range')));
          await tester.tap(find.text('学年'));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2026')), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2025')), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2024')), findsNothing);
          expect(find.text('近几个学年'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await capture('gpa-years');
          await tester.tap(find.byKey(const ValueKey('grade-year-2026')));
          await tester.pumpAndSettle();
          expect(find.text('2.00'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('选择学年后查看课程与 GPA'), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-b')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('2.00'), findsOneWidget);
          await tester.tap(find.text('近学期'));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('grade-recent-less')));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          await capture('gpa-recent');
          await tester.tap(find.text('学期'));
          await tester.pumpAndSettle();
          await capture('gpa-term');
          await tester.tap(find.byKey(const ValueKey('grade-term')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('2026年春季学期').last);
          await tester.pumpAndSettle();
          expect(find.text('2.00'), findsOneWidget);
          await tester.tap(find.text('总绩点'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('排除通识课程'));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          await tester.ensureVisible(find.text('恢复默认选择'));
          await tester.tap(find.text('恢复默认选择'));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await tester.ensureVisible(find.text('计算规则与来源'));
          await tester.tap(find.text('计算规则与来源'));
          await tester.pumpAndSettle();
          expect(find.text('本科生成绩管理办法'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
