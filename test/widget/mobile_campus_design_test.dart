import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'dart:io';
import 'dart:async';
import '../fixtures/layout_test_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/mobile_rollcall_home.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import '../fixtures/preview_fonts.dart';

class _Repo extends Fake implements AuthRepository {}

class _Attendance extends Fake implements RollcallRepository {
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async =>
      const AttendanceCount(36, 48);
}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '林同学'),
    );
  }
}

var _items = <RollcallItem>[];
bool _running = false;
bool _failRefresh = false;

class _Lists extends ActiveRollcallsNotifier {
  void emptyRefresh() => state = const AsyncLoading();
  @override
  Future<List<RollcallItem>> build(int? id) async => _items;
  @override
  Future<void> refresh({bool manual = true}) async {
    state = _failRefresh
        ? AsyncError(StateError('offline'), StackTrace.current)
        : AsyncData(_items);
  }
}

class _Monitor extends MonitorController {
  void debugSeconds(int seconds) => state = state.copyWith(
    nextPollAt: DateTime.now().add(Duration(seconds: seconds)),
  );
  _Monitor(super.ref) {
    state = state.copyWith(
      loadingSettings: false,
      running: _running,
      nextPollAt: _running
          ? DateTime.now().add(const Duration(seconds: 30))
          : null,
    );
  }
}

final _now = DateTime(2026, 10, 28, 10, 12);
Map<String, dynamic> _course(
  String id,
  String title,
  String room,
  int start,
  int end,
) => {
  'KCDM': id,
  'BJDM': 'A',
  'KCMC': title,
  'XQ': 3,
  'KSJCDM': 1,
  'JSJCDM': 2,
  'ZCBH': '1',
  'JASMC': room,
  'startMinute': start,
  'endMinute': end,
};

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
    if (Platform.environment['CAPTURE_HOME_DAY_UI'] == '1') {
      await loadLayoutTestFonts();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dark in [false, true]) {
      for (final mode in [
        'no-class',
        'finished',
        'upcoming',
        'missing',
        'loading',
        'failed',
        'transition',
        'active',
      ]) {
        testWidgets('home day status $mode $platform dark=$dark', (
          tester,
        ) async {
          final narrow = dark && mode == 'no-class';
          final width = narrow ? 320.0 : 390.0;
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final capture = GlobalKey();
          _running = false;
          _items = mode == 'active'
              ? [
                  const RollcallItem(
                    rollcallId: 17,
                    courseTitle: '临时课堂签到',
                    createdByName: '测试教师',
                    type: RollcallType.number,
                    status: 'on_call',
                    rollcallStatus: 'on_call',
                    isExpired: false,
                    scored: false,
                    numberCode: '1234',
                  ),
                ]
              : [];
          final pending = Completer<CampusCachedData>();
          final clock = StreamController<DateTime>.broadcast();
          addTearDown(clock.close);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                activeRollcallsProvider.overrideWith(_Lists.new),
                rollcallRepositoryForProvider(
                  null,
                ).overrideWithValue(_Attendance()),
                monitorControllerProvider.overrideWith(_Monitor.new),
                selectedDetectionWindowProvider.overrideWith(
                  (ref) async => const DetectionWindow(enabled: false),
                ),
                currentCourseHistoryProvider.overrideWithValue(
                  const AsyncData([]),
                ),
                campusNowProvider.overrideWithValue(() => _now),
                campusClockProvider.overrideWith(
                  (ref) =>
                      mode == 'transition' ? clock.stream : Stream.value(_now),
                ),
                campusCachedDataProvider.overrideWith((ref) async {
                  if (mode == 'loading') return pending.future;
                  if (mode == 'failed') throw StateError('offline');
                  return CampusCachedData(
                    hasHomeworkCache: true,
                    schedule: mode == 'missing'
                        ? null
                        : AcademicSchedule(
                            term: '20261',
                            monday: DateTime(2026, 10, 26),
                            fetchedAt: _now,
                            rows: mode == 'no-class' || mode == 'active'
                                ? []
                                : [
                                    AcademicCourseRow.fromJson(
                                      _course(
                                        '1',
                                        '测试课程',
                                        'A101',
                                        480,
                                        mode == 'finished' ? 600 : 800,
                                      ),
                                    ),
                                  ],
                          ),
                  );
                }),
              ],
              child: RepaintBoundary(
                key: capture,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: desktopCaptureTheme(
                    dark ? AppTheme.dark() : AppTheme.light(),
                  ).copyWith(platform: platform),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: MobileRollcallHome(
                      controller: scroll,
                      accountMenu: RollcallAccountMenu(
                        masthead: true,
                        mastheadTitle: '签到',
                        value: 0,
                        identities: const [],
                        ownerName: '林同学',
                        onChanged: (_) {},
                      ),
                      scope: null,
                      updatedLabel: '更新于 10:12',
                      onHistory: () {},
                      onSettings: () {},
                      onTimetable: () {},
                      onHomework: () {},
                      onOpenHomework: (_) {},
                      onRetryIdentity: () {},
                    ),
                    bottomNavigationBar: AppMobileNav(
                      current: AppDestination.rollcall,
                      onSelect: (_) {},
                      onSearch: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final message = find.byKey(const ValueKey('rollcall-day-empty'));
          final empty = mode == 'no-class' || mode == 'finished';
          expect(message, empty ? findsOneWidget : findsNothing);
          expect(
            find.text('今日课程'),
            empty || mode == 'active' ? findsNothing : findsOneWidget,
          );
          if (empty) {
            expect(
              find.text(mode == 'no-class' ? '今天没有课程' : '今天的课程已结束'),
              findsOneWidget,
            );
            final top = tester
                .getRect(find.byKey(const ValueKey('mobile-context-surface')))
                .bottom;
            final bottom = platform == TargetPlatform.iOS
                ? tester
                      .getRect(
                        find.byKey(const ValueKey('mobile-history-footer')),
                      )
                      .top
                : tester.getRect(find.byType(CustomScrollView)).bottom;
            expect(tester.getCenter(message).dx, closeTo(width / 2, 1));
            expect(
              tester.getCenter(message).dy,
              closeTo((top + bottom) / 2, 25),
            );
          }
          expect(tester.takeException(), isNull);
          if (mode == 'transition') {
            clock.add(DateTime(2026, 10, 28, 13, 20));
            await tester.pumpAndSettle();
            expect(find.text('今日课程'), findsNothing);
            expect(find.text('今天的课程已结束'), findsOneWidget);
            clock.add(DateTime(2026, 10, 29));
            await tester.pumpAndSettle();
            expect(find.text('今天没有课程'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          if (Platform.environment['CAPTURE_HOME_DAY_UI'] == '1' && empty) {
            await tester.runAsync(() async {
              final im =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
              await Directory('build/home-day-ui').create(recursive: true);
              await File(
                'build/home-day-ui/$mode-${platform.name}-$dark.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              im.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final state in ['idle', 'active', 'running', 'done', 'long']) {
      testWidgets('mobile campus $state dark=$dark stays usable and sparse', (
        tester,
      ) async {
        final narrow = state == 'long';
        tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var opened = 0;
        _running = state == 'running';
        _failRefresh = false;
        _items = state == 'idle'
            ? []
            : [
                RollcallItem(
                  rollcallId: 10,
                  courseTitle: narrow ? '非常长的专业英语课程名称以及研究生实践与应用课程' : '专业英语',
                  createdByName: '陈老师',
                  type: RollcallType.radar,
                  status: state == 'done' ? 'on_call_fine' : '',
                  rollcallStatus: '',
                  isExpired: false,
                  scored: false,
                ),
              ];
        final capture = GlobalKey();
        final destination = ValueNotifier(AppDestination.rollcall);
        addTearDown(destination.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => _Auth()),
              activeRollcallsProvider.overrideWith(_Lists.new),
              rollcallRepositoryForProvider(
                null,
              ).overrideWithValue(_Attendance()),
              selectedDetectionWindowProvider.overrideWith(
                (ref) async => const DetectionWindow(enabled: false),
              ),
              monitorControllerProvider.overrideWith(_Monitor.new),
              campusNowProvider.overrideWithValue(() => _now),
              campusClockProvider.overrideWith((ref) => Stream.value(_now)),
              campusCachedDataProvider.overrideWith(
                (ref) async => CampusCachedData(
                  schedule: AcademicSchedule(
                    term: '20261',
                    monday: DateTime(2026, 10, 26),
                    fetchedAt: _now,
                    rows: [
                      _course('1', '专业英语', '学武楼（1号楼）A404', 610, 710),
                      _course('2', '软件测试', '西部片区2号楼108', 870, 970),
                    ].map(AcademicCourseRow.fromJson).toList(),
                  ),
                  hasHomeworkCache: true,
                  homework: [
                    HomeworkItem(
                      id: 1,
                      title: narrow ? '非常长的大作业标题需要显示省略号' : '大作业',
                      courseName: narrow ? '非常长的云计算技术与软件工程理论课程' : '云计算技术',
                      dueAt: DateTime(2026, 11, 1, 23, 59),
                    ),
                  ],
                ),
              ),
              currentCourseHistoryProvider.overrideWithValue(
                AsyncData([
                  CourseRollcallRecord(
                    courseId: '1',
                    courseTitle: '专业英语',
                    rollcallId: '9',
                    rollcallTime: DateTime(2026, 10, 27, 16, 42),
                    typeLabel: '定位签到',
                    signedStatus: '未签到',
                    platformStatus: '',
                  ),
                ]),
              ),
            ],
            child: RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: TargetPlatform.android,
                ),
                builder: (context, child) =>
                    ValueListenableBuilder<AppDestination>(
                      valueListenable: destination,
                      builder: (context, current, _) => ShellTabScope(
                        current: current,
                        retapEpoch: 0,
                        retapDestination: null,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(narrow ? 1.3 : 1),
                          ),
                          child: child!,
                        ),
                      ),
                    ),
                home: Scaffold(
                  body: MobileRollcallHome(
                    controller: scroll,
                    scope: null,
                    accountMenu: RollcallAccountMenu(
                      masthead: true,
                      mastheadTitle: '签到',
                      value: 0,
                      identities: const [],
                      ownerName: '林同学',
                      onChanged: (_) {},
                    ),
                    updatedLabel: '更新于 10:12',
                    onHistory: () {},
                    onSettings: () {},
                    onTimetable: () {},
                    onHomework: () {},
                    onRetryIdentity: () {},
                    onOpenHomework: (item) {
                      opened++;
                    },
                  ),
                  bottomNavigationBar: AppMobileNav(
                    current: AppDestination.rollcall,
                    onSelect: (_) {},
                    onSearch: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final titleRect = tester.getRect(find.text('签到').first);
        final dateRect = tester.getRect(
          find.byKey(const ValueKey('mobile-home-date')),
        );
        expect(dateRect.left, titleRect.left);
        expect(dateRect.top, greaterThanOrEqualTo(titleRect.bottom));
        final startTime = tester.widget<Text>(find.text('10:10'));
        expect(startTime.maxLines, isNull);
        expect(startTime.softWrap, isNull);
        expect(find.text('即将开始'), findsNothing);
        expect(
          find.text('尚未开始检测'),
          state == 'idle' ? findsOneWidget : findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, '选择位置'),
          state == 'idle' || state == 'done' ? findsNothing : findsOneWidget,
        );
        if (state == 'done') expect(find.text('已签到'), findsOneWidget);
        final header = find.byKey(const ValueKey('mobile-rollcall-header'));
        expect(
          tester.getTopLeft(find.text('签到').first).dy -
              tester.getTopLeft(header).dy,
          lessThan(32),
          reason: 'Title stays near the top of the plain header',
        );
        if (state == 'idle') {
          expect(
            tester.getBottomLeft(find.text('尚未开始检测')).dy,
            lessThanOrEqualTo(tester.getBottomLeft(header).dy),
          );
          expect(
            tester.getRect(find.text('开始检测')).overlaps(tester.getRect(header)),
            true,
          );
        }
        if (Platform.environment['CAPTURE_MOBILE_CAMPUS'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/mobile-campus-design',
            ).create(recursive: true);
            await File(
              'build/mobile-campus-design/$state-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (state == 'idle') {
          await tester
              .widget<AppPullToRefresh>(find.byType(AppPullToRefresh))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(find.text('暂无正在签到的课程'), findsOneWidget);
          _failRefresh = true;
          await tester
              .widget<AppPullToRefresh>(find.byType(AppPullToRefresh))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(find.text('暂时无法确认签到状态'), findsOneWidget);
          expect(find.text('暂无正在签到的课程'), findsNothing);
          _failRefresh = false;
          await tester
              .widget<AppPullToRefresh>(find.byType(AppPullToRefresh))
              .onRefresh();
          await tester.pumpAndSettle();

          destination.value = AppDestination.settings;
          await tester.pump();
          destination.value = AppDestination.rollcall;
          await tester.pump();
          expect(find.text('尚未开始检测'), findsOneWidget);
        }
        if (state == 'running') {
          final control = find.byKey(const ValueKey('monitor-countdown-width'));
          final width = tester.getSize(control).width;
          final monitor =
              ProviderScope.containerOf(
                    tester.element(find.byType(MobileRollcallHome)),
                  ).read(monitorControllerProvider.notifier)
                  as _Monitor;
          monitor.debugSeconds(100);
          await tester.pump();
          expect(tester.getSize(control).width, width);
          monitor.debugSeconds(9);
          await tester.pump();
          expect(tester.getSize(control).width, width);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MobileRollcallHome)),
          );
          (container.read(activeRollcallsProvider(null).notifier) as _Lists)
              .emptyRefresh();
          await tester.pump();
          expect(
            find.text('停止检测'),
            findsOneWidget,
            reason:
                'Refresh must not replace the running stop control with a spinner',
          );
        }
        expect(find.text('待办事项'), findsNothing);
        expect(find.textContaining('上次签到'), findsNothing);
        expect(opened, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
