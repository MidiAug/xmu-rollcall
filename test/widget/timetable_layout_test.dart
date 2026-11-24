import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/shell_destination_scope.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';

class _AuthRepository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '预览同学'),
    );
  }
}

class _Catalog extends CourseCatalogNotifier {
  _Catalog(this.courses);
  final List<CatalogCourse> courses;
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: DateTime(2026, 10, 23, 20, 30),
    courses: courses,
  );
}

List<CatalogCourse> _courses(bool weekend) {
  final clock = [
    (8, 0),
    (8, 55),
    (10, 10),
    (11, 5),
    (14, 30),
    (15, 25),
    (16, 40),
    (17, 35),
    (19, 10),
    (20, 5),
    (21, 0),
  ];
  CatalogCourse course(String id, String title, int day, int start, int end) =>
      CatalogCourse(
        id: id,
        title: title,
        teachingClassName: '信息 1 班',
        instructorNames: const ['陈老师'],
        location: id == 'single'
            ? '示例教学楼完整地点名称很长时应保留前部并裁切后部 A101'
            : id == 'late'
            ? '海韵教学楼 205'
            : null,
        timetables: {
          day: [
            for (var seq = start; seq <= end; seq++)
              TimetableSlot(
                sequence: seq,
                start: DateTime(
                  2000,
                  1,
                  3,
                  clock[seq - 1].$1,
                  clock[seq - 1].$2,
                ),
                end: DateTime(
                  2000,
                  1,
                  3,
                  clock[seq - 1].$1,
                  clock[seq - 1].$2 + 45,
                ),
              ),
          ],
        },
      );
  return [
    course('ethics', '工程伦理', 1, 1, 2),
    course('writing', '科技论文写作', 2, 5, 6),
    course('english', '专业英语', 3, 3, 4),
    course('software', '软件测试与程序分析基础', 1, 5, 6),
    course('programming', 'C 语言程序设计', 4, 7, 8),
    course('ml', '机器学习', 5, 2, 4),
    course('single', '专题研讨', 2, 1, 1),
    course('late', '深度学习', 5, 9, 11),
    if (weekend) course('sat', '周末实验', 6, 3, 4),
    if (weekend) course('sun', '周末研讨', 7, 5, 6),
  ];
}

/// Keep grid/location regressions independent of the direct JW data source.
class _GridHarness extends ConsumerWidget {
  const _GridHarness();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SubpageScaffold(
    title: '课表',
    body: TimetableGridView(
      courses:
          ref.watch(courseCatalogProvider).valueOrNull?.courses ?? const [],
    ),
  );
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(title: '厦大签到'),
          Container(height: 1, color: p.border),
          Expanded(
            child: Row(
              children: [
                AppSidebar(
                  current: AppDestination.settings,
                  userLabel: '预览同学',
                  onSelect: (_) {},
                ),
                Container(width: 1, color: p.border),
                Expanded(
                  child: ShellTabDestination(
                    destination: AppDestination.settings,
                    child: Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => const _GridHarness(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  initializeDesktopUiCapture();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final cache = await Directory(
      '.tools/timetable-polish/cache',
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
    final font = Platform.environment['SETTINGS_UI_FONT'];
    if (font == null) return;
    await (FontLoader(
      'TimetableUi',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            Platform.environment['SETTINGS_UI_ICONS']!,
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  for (final (width, scale) in [(960.0, 1.0), (320.0, 1.5)]) {
    testWidgets(
      'week and semester keep header and first course aligned at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> show(bool dates) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: TimetableGridView(
                    courses: _courses(false),
                    showDates: dates,
                    referenceDate: DateTime(2026, 11, 20),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(true);
        final weekly = tester.getRect(
          find.byKey(const ValueKey('timetable-weekdays')),
        );
        final courseTop = tester.getTopLeft(find.text('专题研讨')).dy;
        await show(false);
        expect(
          tester.getRect(find.byKey(const ValueKey('timetable-weekdays'))),
          weekly,
        );
        expect(tester.getTopLeft(find.text('专题研讨')).dy, closeTo(courseTop, .1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'stack chooser opens actual course detail $width dark=$dark',
        (tester) async {
          Offset? detailCloseOffset;
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final choices = [
            for (var n = 0; n < 2; n++)
              CatalogCourse(
                id: 'academic:stack-$n',
                title: n == 0 ? '第一门课程的完整长名称' : '第二门课程',
                location: '教学楼 A10$n',
                instructorNames: const ['陈老师'],
                timetables: {
                  1: [
                    TimetableSlot(
                      sequence: 1,
                      endSequence: 2,
                      start: DateTime(2000, 1, 3, 8),
                      end: DateTime(2000, 1, 3, 9, 40),
                      dates: {n == 0 ? '2026-11-16' : '2026-11-23'},
                      weekLabel: n == 0 ? '第11周' : '第12周',
                    ),
                  ],
                },
              ),
          ];
          await tester.pumpWidget(
            ProviderScope(
              child: RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  home: Scaffold(
                    body: TimetableGridView(
                      courses: choices,
                      referenceDate: DateTime(2026, 11, 16),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('第一门课程的完整长名称'));
          await tester.pumpAndSettle();
          expect(find.text('同一时段的课程'), findsOneWidget);
          expect(find.text('第二门课程'), findsOneWidget);
          await captureDesktopUi(
            tester,
            'timetable-overlap-${width.toInt()}-$dark',
          );
          await tester.tap(find.text('第二门课程'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('关闭课程详情'), findsOneWidget);
          if (width == 960.0) {
            final flow = find.byKey(const ValueKey('course-detail-flow'));
            final detailClose = find.byTooltip('关闭课程详情');
            final detailCloseIcon = find.descendant(of: detailClose, matching: find.byType(Icon));
            final detailCloseRect = tester.getRect(detailClose);
            expect(detailCloseRect.size, const Size(34, 34));
            expect((tester.getCenter(detailCloseIcon) - detailCloseRect.center).distance, lessThan(1.0));
            detailCloseOffset = detailCloseRect.topRight - tester.getRect(flow).topRight;
          }
          expect(find.text('第12周'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('course-location-map-link')),
              matching: find.text('教学楼 A101'),
            ),
            findsOneWidget,
          );
          await captureDesktopUi(
            tester,
            'timetable-detail-${width.toInt()}-$dark',
          );
          await tester.tap(
            find.byKey(const ValueKey('course-location-map-link')),
          );
          await tester.pumpAndSettle();
          if (width == 960.0) {
            final flow = find.byKey(const ValueKey('course-detail-flow'));
            final mapBack = find.byTooltip('返回课程');
            final mapBackIcon = find.descendant(
              of: mapBack,
              matching: find.byType(Icon),
            );
            final mapBackRect = tester.getRect(mapBack);
            expect(mapBackRect.size, const Size(34, 34));
            expect(
              (tester.getCenter(mapBackIcon) - mapBackRect.center).distance,
              lessThan(1.0),
            );
            final mapClose = find.byTooltip('关闭');
            final mapCloseRect = tester.getRect(mapClose);
            expect(mapCloseRect.size, const Size(34, 34));
            final mapCloseOffset = mapCloseRect.topRight - tester.getRect(flow).topRight;
            expect((detailCloseOffset!.dx - mapCloseOffset.dx).abs(), lessThan(1.0));
            expect((detailCloseOffset.dy - mapCloseOffset.dy).abs(), lessThan(6.0));
          }
          expect(find.byType(CampusMap), findsOneWidget);
          expect(find.byType(MapAttributionControls), findsOneWidget);
          await captureDesktopUi(
            tester,
            'timetable-map-${width.toInt()}-$dark',
          );
          await tester.tap(find.byTooltip('返回课程'));
          await tester.pumpAndSettle();
          if (width == 960.0) {
            final returnedCloseOffset =
                tester.getRect(find.byTooltip('关闭课程详情')).topRight -
                tester.getRect(find.byKey(const ValueKey('course-detail-flow'))).topRight;
            expect((returnedCloseOffset - detailCloseOffset!).distance, lessThan(0.5));
          }
          await tester.tap(find.byTooltip('关闭课程详情'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('切换课次（1/2）'), findsOneWidget);
          await tester.tap(find.byTooltip('切换课次（1/2）'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('切换课次（2/2）'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('week header dates cross a year boundary without marking today', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // A different week also guards against applying today's weekday highlight to
    // the same column in a different displayed week.
    final reference = DateTime(2009, 12, 31);
    final monday = DateTime(
      reference.year,
      reference.month,
      reference.day - reference.weekday + 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimetableGridView(
              courses: _courses(false),
              referenceDate: reference,
              showDates: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var day = 1; day <= 5; day++) {
      final date = monday.add(Duration(days: day - 1));
      expect(
        tester.widget<Text>(find.byKey(ValueKey('timetable-date-$day'))).data,
        '${date.month}/${date.day}',
      );
      final dateLabel = find.byKey(ValueKey('timetable-date-$day'));
      final weekday = find.text(weekdayLabel(day));
      expect(
        tester.getCenter(dateLabel).dy,
        closeTo(tester.getCenter(weekday).dy, 2),
      );
      expect(
        tester.getRect(dateLabel).left,
        greaterThan(tester.getRect(weekday).right),
      );
      final header = tester.widget<DecoratedBox>(
        find.byKey(ValueKey('timetable-day-$day')),
      );
      expect((header.decoration as BoxDecoration).color, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: 'desktop-light',
      width: 960.0,
      dark: false,
      scale: 1.0,
      weekend: false,
    ),
    (
      name: 'desktop-dark',
      width: 960.0,
      dark: true,
      scale: 1.0,
      weekend: false,
    ),
    (
      name: 'desktop-large-weekend',
      width: 960.0,
      dark: false,
      scale: 1.3,
      weekend: true,
    ),
    (
      name: 'mobile-light',
      width: 384.0,
      dark: false,
      scale: 1.0,
      weekend: false,
    ),
    (
      name: 'mobile-large-weekend',
      width: 320.0,
      dark: true,
      scale: 1.3,
      weekend: true,
    ),
  ]) {
    testWidgets(
      'timetable remains readable, scrollable and interactive: ${scenario.name}',
      (tester) async {
        final desktop = scenario.width >= 600;
        tester.view.physicalSize = Size(scenario.width, desktop ? 720 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var theme = scenario.dark ? AppTheme.dark() : AppTheme.light();
        if (Platform.environment['SETTINGS_UI_FONT'] != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'TimetableUi'),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.merge(
                TextButton.styleFrom(
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'TimetableUi',
                  ),
                ),
              ),
            ),
          );
        }
        final key = GlobalKey();
        Future<void> capture(String state) async {
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_TIMETABLE_UI'] != '1') return;
          await tester.runAsync(() async {
            final directory = await Directory(
              '.tools/timetable-polish',
            ).create(recursive: true);
            final img =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${directory.path}/${scenario.name}-$state.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                courseCatalogProvider.overrideWith(
                  () => _Catalog(_courses(scenario.weekend)),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: desktop ? const _DesktopFrame() : const _GridHarness(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TimetableGridView), findsOneWidget);
        final room = find.text('示例教学楼完整地点名称很长时应保留前部并裁切后部 A101');
        expect(
          room,
          findsOneWidget,
          reason: 'A single period still reserves the full room caption',
        );
        expect(tester.widget<Text>(room).overflow, TextOverflow.ellipsis);
        expect(
          tester.widget<Text>(find.text('工程伦理')).style!.fontSize,
          greaterThanOrEqualTo(desktop ? 13 : 11),
        );
        await capture('01-top');
        final weekdays = find.byKey(const ValueKey('timetable-weekdays'));
        final top = tester.getTopLeft(weekdays).dy;
        await tester.drag(
          find.byKey(const ValueKey('timetable-vertical')),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(weekdays).dy, top);
        if (scenario.weekend) {
          final periods = find.byKey(const ValueKey('timetable-periods'));
          final axisLeft = tester.getTopLeft(periods).dx;
          await tester.drag(
            find.byKey(const ValueKey('timetable-horizontal')),
            const Offset(-600, 0),
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(periods).dx, axisLeft);
          expect(find.text('周日').hitTestable(), findsOneWidget);
        }
        await capture('02-late');
        final late = find.byKey(const ValueKey('course-late-5-9-11'));
        expect(late.hitTestable(), findsOneWidget);
        await tester.tap(late);
        await tester.pumpAndSettle();
        expect(find.text('海韵教学楼 205'), findsWidgets);
        expect(find.byTooltip('关闭课程详情'), findsOneWidget);
        if (!desktop) {
          expect(
            tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
            isFalse,
          );
        }
        expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
        expect(find.text('签到地点'), findsOneWidget);
        expect(find.text('教务教室'), findsNothing);
        await capture('03-detail');
        final flow = find.byKey(const ValueKey('course-detail-flow'));
        final width = tester.getSize(flow).width;
        final barriers = find.byType(ModalBarrier).evaluate().length;
        await tester.tap(find.byKey(const ValueKey('course-location-picker')));
        await tester.pumpAndSettle();
        expect(find.byType(ModalBarrier), findsNWidgets(barriers));
        expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
        expect(tester.getSize(flow).width, width);
        expect(find.byTooltip('返回课程详情'), findsOneWidget);
        await capture('04-location');
        await tester.tap(find.text('添加地点'));
        await tester.pumpAndSettle();
        expect(find.byType(MapPickPanel), findsOneWidget);
        expect(find.byType(ModalBarrier), findsNWidgets(barriers));
        expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
        expect(tester.getSize(flow).width, width);
        await capture('05-add-location');
        if (!desktop) {
          final note = find.byKey(const ValueKey('location-note-input'));
          await tester.tap(note);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(tester.getBottomRight(note).dy, lessThanOrEqualTo(844 - 300));
          expect(tester.takeException(), isNull);
          await capture('05a-keyboard');
          tester.view.resetViewInsets();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MapPickPanel), findsNothing);
        await capture('05b-after-back');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await capture('05c-after-second-back');
        expect(find.byTooltip('关闭课程详情'), findsOneWidget);
        final container = ProviderScope.containerOf(tester.element(flow));
        await container
            .read(savedLocationsProvider.notifier)
            .add(note: '新的上课地点', latitude: 24.6, longitude: 118.3);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('course-location-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('新的上课地点'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('关闭课程详情'), findsOneWidget);
        expect(find.text('新的上课地点'), findsOneWidget);
        expect(
          container
              .read(courseRadarDefaultsProvider.notifier)
              .forCourse(courseId: 'late')
              ?.labelSnapshot,
          '新的上课地点',
        );
        expect(find.byType(ModalBarrier), findsNWidgets(barriers));
        await capture('06-location-selected');
        AppToast.dismiss();
        await tester.tap(find.byTooltip('关闭课程详情'));
        await tester.pumpAndSettle();
        if (desktop) {
          final title = find
              .descendant(of: late, matching: find.byType(Text))
              .first;
          Focus.of(tester.element(title)).requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'course detail location link uses primary color without underline or muted placeholder dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        CatalogCourse makeCourse(String id, String title, int day, String? loc) =>
            CatalogCourse(
              id: id,
              title: title,
              instructorNames: const ['陈老师'],
              location: loc,
              timetables: {
                day: [
                  TimetableSlot(
                    sequence: 1,
                    endSequence: 2,
                    start: DateTime(2000, 1, 3, 8),
                    end: DateTime(2000, 1, 3, 9, 40),
                  ),
                ],
              },
            );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                body: TimetableGridView(
                  courses: [
                    makeCourse('with-room', '有地点课程', 1, '海韵教学楼 205'),
                    makeCourse('no-room', '无地点课程', 2, null),
                  ],
                  referenceDate: DateTime(2026, 11, 20),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('有地点课程'));
        await tester.pumpAndSettle();
        final linkRowFinder = find.byKey(
          const ValueKey('course-location-map-link'),
        );
        expect(linkRowFinder, findsOneWidget);
        final linkPalette = AppPalette.of(tester.element(linkRowFinder));
        final linkRow = tester.widget<SettingsRow>(linkRowFinder);
        expect(linkRow.onTap, isNotNull);

        final locationText = tester.widget<Text>(
          find.descendant(
            of: linkRowFinder,
            matching: find.text('海韵教学楼 205'),
          ),
        );
        expect(locationText.style?.color, linkPalette.primary);
        expect(locationText.style?.decoration, isNot(TextDecoration.underline));

        final arrowFinder = find.descendant(
          of: linkRowFinder,
          matching: find.byIcon(AppIcons.right),
        );
        expect(arrowFinder, findsOneWidget);
        final arrowIcon = tester.widget<Icon>(arrowFinder);
        expect(arrowIcon.size, 16);
        expect(arrowIcon.color, linkPalette.primary);

        await tester.tap(find.byTooltip('关闭课程详情'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('无地点课程'));
        await tester.pumpAndSettle();
        expect(linkRowFinder, findsOneWidget);
        final emptyPalette = AppPalette.of(tester.element(linkRowFinder));
        final emptyRow = tester.widget<SettingsRow>(linkRowFinder);
        expect(emptyRow.onTap, isNull);

        final emptyText = tester.widget<Text>(
          find.descendant(
            of: linkRowFinder,
            matching: find.text('教务未提供教室'),
          ),
        );
        expect(emptyText.style?.color, emptyPalette.muted);
        expect(emptyText.style?.decoration, isNot(TextDecoration.underline));
        expect(
          find.descendant(
            of: linkRowFinder,
            matching: find.byIcon(AppIcons.right),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'course detail long instructors single line truncation and icons test',
    (tester) async {
      tester.view.physicalSize = const Size(600, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final course = CatalogCourse(
        id: 'long-instr',
        title: '多教师课程',
        instructorNames: const [
          '王程',
          '臧彧',
          '温程璐',
          '沈思琪',
          '范晓亮',
          '陈老师',
          '李老师',
        ],
        location: '海韵教学楼 205',
        timetables: {
          1: [
            TimetableSlot(
              sequence: 1,
              endSequence: 2,
              start: DateTime(2000, 1, 3, 8),
              end: DateTime(2000, 1, 3, 9, 40),
            ),
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TimetableGridView(
                courses: [course],
                referenceDate: DateTime(2026, 11, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('多教师课程'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSettingsGlyph), findsWidgets);
      expect(find.byWidgetPredicate((w) => w is AppSettingsGlyph && w.kind == AppSettingsGlyphKind.user), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is AppSettingsGlyph && w.kind == AppSettingsGlyphKind.mapPin), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is AppSettingsGlyph && w.kind == AppSettingsGlyphKind.clock), findsOneWidget);
      // block.weekLabel is null in this test slot, so calendar glyph is not rendered.
      expect(find.byWidgetPredicate((w) => w is AppSettingsGlyph && w.kind == AppSettingsGlyphKind.calendar), findsNothing);

      final instructorTextFinder = find.text('王程、臧彧、温程璐、沈思琪、范晓亮、陈老师、李老师');
      expect(instructorTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(instructorTextFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      final paragraph = tester.renderObject<RenderParagraph>(instructorTextFinder);
      expect(paragraph.didExceedMaxLines, isTrue);

      expect(find.byType(Tooltip), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
