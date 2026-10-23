import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
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
        location: id == 'late' ? '海韵教学楼 205' : null,
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

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.chrome});
  final DesktopShellChromeController chrome;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DesktopShellChromeScope(
      controller: chrome,
      child: Scaffold(
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
                          builder: (_) => const CoursesPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
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
        final chrome = DesktopShellChromeController()
          ..current = AppDestination.settings;
        addTearDown(chrome.dispose);
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
                home: desktop
                    ? _DesktopFrame(chrome: chrome)
                    : const CoursesPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TimetableGridView), findsOneWidget);
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
        expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
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
}
