import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/desktop/desktop_page.dart';
import 'package:xmu_rollcall/app/desktop/desktop_workspace.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/campus/campus_context_panel.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import '../fixtures/update_fakes.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '林同学'),
    );
  }
}

class _Attendance extends Fake implements RollcallRepository {
  int loads = 0;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async {
    loads++;
    return const AttendanceCount(36, 48);
  }
}

class _Assist extends Fake implements AssistService {
  @override
  Future<void> ensureSession(AssistIdentity identity) async {}
  @override
  Future<AssistIdentity> ensureDeviceId(AssistIdentity identity) async =>
      identity;
}

class _Rollcalls extends ActiveRollcallsNotifier {
  static int refreshes = 0;
  @override
  Future<List<RollcallItem>> build(int? id) async => const [
    RollcallItem(
      rollcallId: 7,
      courseTitle: '机器学习',
      createdByName: '陈老师',
      type: RollcallType.number,
      status: 'on_call',
      rollcallStatus: 'on_call',
      isExpired: false,
      scored: false,
      numberCode: '6428',
      raw: {'course_id': '7'},
    ),
  ];
  @override
  Future<void> refresh({bool manual = true}) async {
    refreshes++;
  }
}

final now = DateTime(2026, 10, 28, 14, 50);
final schedule = AcademicSchedule(
  term: '20261',
  monday: DateTime(2026, 10, 26),
  fetchedAt: now,
  rows: [
    for (final c in [
      ('old', '已结束课程', 480, 570),
      ('current', '机器学习', 870, 970),
      ('next', '软件测试', 1000, 1100),
      ('later', '更晚课程', 1150, 1240),
    ])
      {
        'KCDM': c.$1,
        'BJDM': 'A',
        'KCMC': c.$2,
        'XQ': 3,
        'KSJCDM': 5,
        'JSJCDM': 6,
        'ZCBH': '1',
        'JASMC': c.$1 == 'next' ? '教学楼 A203' : '教学楼 A301',
        'startMinute': c.$3,
        'endMinute': c.$4,
      },
  ].map(AcademicCourseRow.fromJson).toList(),
);
final homework = [
  HomeworkItem(
    id: 3,
    title: '软件工程导论实验报告',
    courseId: 7,
    courseName: '软件工程导论',
    dueAt: DateTime(2026, 10, 29, 23, 59),
  ),
  HomeworkItem(
    id: 4,
    title: '课程阅读',
    courseId: 7,
    dueAt: DateTime(2026, 10, 30, 23, 59),
  ),
  HomeworkItem(
    id: 5,
    title: '实验一报告',
    courseId: 7,
    courseName: '机器学习',
    dueAt: DateTime(2026, 10, 26),
    closed: true,
  ),
  HomeworkItem(
    id: 6,
    title: '项目展示',
    courseId: 7,
    courseName: '软件工程导论',
    dueAt: DateTime(2026, 10, 31),
  ),
];
final peerSchedule = AcademicSchedule(
  term: schedule.term,
  monday: schedule.monday,
  fetchedAt: now,
  rows: [
    {...schedule.rows[1].toJson(), 'KCMC': '账号二课程'},
  ].map(AcademicCourseRow.fromJson).toList(),
);

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => homework;
  @override
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {}
}

class _TeachingTasks extends CourseHomeworkNotifier {
  @override
  Future<List<HomeworkItem>> build(int id) async => [
    HomeworkItem(
      id: 90,
      courseId: id,
      title: '助教课程的作业标题很长时应保持单行或受限行数，不溢出到右侧时间与箭头',
      dueAt: DateTime(2026, 10, 31, 23, 59),
    ),
  ];
}

class _Overview extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async => HomeworkOverview(homework);
  @override
  Future<bool> ensureFresh({bool force = false}) async => true;
}

class _Catalog extends CourseCatalogNotifier {
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: now,
    courses: const [CatalogCourse(id: '7', title: '机器学习')],
  );
}

void main() {
  initializeDesktopUiCapture();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final material = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (material.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(material.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final variant in [
    (900.0, 640.0, false, 1.0, 1.0),
    (900.0, 640.0, false, 1.0, 2.0),
    (960.0, 720.0, false, 1.0, 1.0),
    (1120.0, 780.0, false, 1.0, 1.0),
    (1440.0, 1024.0, true, 1.0, 2.0),
    (1120.0, 820.0, false, 1.3, 1.0),
  ]) {
    testWidgets(
      'desktop workspace and actual two-course context $variant',
      // Keep the full retained-page flow together, including account switches.
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'theme_preference': variant.$3 ? 1 : 2,
          'local_rollcall_history_1': jsonEncode([
            RollcallHistoryEntry(
              rollcallId: 6,
              courseTitle: '工程伦理',
              typeLabel: '数字',
              ok: true,
              at: DateTime(2026, 10, 28, 8, 20),
            ).toJson(),
          ]),
        });
        tester.view.devicePixelRatio = variant.$5;
        tester.view.physicalSize = Size(
          variant.$1 * variant.$5,
          variant.$2 * variant.$5,
        );
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await AcademicScheduleStore.write(1, schedule);
        final boundary = GlobalKey();
        final attendance = _Attendance();
        final contextData = StateProvider<CampusCachedData>(
          (ref) => CampusCachedData(
            schedule: schedule,
            homework: homework.where((i) => i.id == 3 || i.id == 6).toList(),
            hasHomeworkCache: true,
          ),
        );
        final pendingContext = StateProvider<Future<CampusCachedData>?>(
          (ref) => null,
        );
        final contextTime = StateProvider<DateTime>((ref) => now);
        final theme = variant.$3 ? AppTheme.dark() : AppTheme.light();
        final update = AppUpdateController(
          service: FakeUpdateService(),
          package: () async => PackageInfo(
            appName: 'test',
            packageName: 'test',
            version: '0.3.0',
            buildNumber: '6',
          ),
          target: UpdateTarget.windows,
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              overrides: [
                secureStoreProvider.overrideWithValue(SecureStore.memory()),
                authControllerProvider.overrideWith((ref) => _Auth()),
                assistControllerProvider.overrideWith(
                  (ref) => AssistController(
                    ref,
                    bootstrap: false,
                    initial: const AssistUiState(
                      ready: true,
                      identities: [
                        AssistIdentity(
                          userId: 2,
                          displayName: '测试同学',
                          kind: AssistCredentialKind.session,
                          deviceId: 'fixture-device-2',
                        ),
                      ],
                    ),
                  ),
                ),
                assistServiceProvider.overrideWith((ref) async => _Assist()),
                activeRollcallsProvider.overrideWith(_Rollcalls.new),
                activeRollcallClockProvider.overrideWithValue(() => now),
                rollcallRepositoryForProvider(
                  null,
                ).overrideWithValue(attendance),
                rollcallRepositoryForProvider(
                  2,
                ).overrideWithValue(_Attendance()),
                currentCourseHistoryProvider.overrideWithValue(
                  AsyncData([
                    CourseRollcallRecord(
                      courseId: '7',
                      courseTitle: '历史中最新的未签到课程',
                      rollcallId: '100',
                      rollcallTime: DateTime(2026, 10, 28, 9),
                      typeLabel: '数字',
                      signedStatus: '未签到',
                      platformStatus: 'closed',
                    ),
                  ]),
                ),
                campusCachedDataProvider.overrideWith((ref) async {
                  final data = ref.watch(contextData);
                  return ref.watch(pendingContext) ?? data;
                }),
                campusClockProvider.overrideWith(
                  (ref) => Stream.value(ref.watch(contextTime)),
                ),
                academicTimetableProvider(1).overrideWith(
                  (ref) async => AcademicTimetableState(schedule: schedule),
                ),
                academicTimetableProvider(2).overrideWith(
                  (ref) async => AcademicTimetableState(schedule: peerSchedule),
                ),
                courseCatalogProvider.overrideWith(_Catalog.new),
                currentTeachingCoursesProvider.overrideWith(
                  (ref) async => const [
                    CatalogCourse(
                      id: '9',
                      title: '助教课程示例：课程名称很长时应在一行内截断，不能撑开页面或挤出边界',
                      roles: ['instructor_assistant'],
                    ),
                  ],
                ),
                courseHomeworkProvider.overrideWith(_TeachingTasks.new),
                homeworkDetailProvider.overrideWith(
                  (ref, key) async => key.seed!,
                ),
                homeworkTodosProvider.overrideWith(_Todos.new),
                homeworkOverviewProvider.overrideWith(_Overview.new),
                homeworkSubmissionProvider.overrideWith(
                  (ref, key) async => HomeworkSubmissionState(
                    submission: key.activityId == 4 || key.activityId == 5
                        ? HomeworkSubmission.submitted
                        : HomeworkSubmission.unsubmitted,
                    grading: key.activityId == 5
                        ? HomeworkGrading.graded
                        : HomeworkGrading.pending,
                    score: key.activityId == 5 ? 92 : null,
                  ),
                ),
                appUpdateControllerProvider.overrideWith((ref) => update),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(platform: TargetPlatform.windows),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(variant.$4)),
                  child: child!,
                ),
                home: const AdaptiveShell(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sidebar = find.byType(AppSidebar);
        expect(
          find.descendant(of: sidebar, matching: find.byType(BrandMark)),
          findsNothing,
        );
        expect(
          find.descendant(of: sidebar, matching: find.text('厦大签到')),
          findsNothing,
        );
        expect(find.text('6428'), findsOneWidget);
        final refreshes = _Rollcalls.refreshes;
        await tester.tap(find.byType(AppRefreshButton).first);
        await tester.pumpAndSettle();
        expect(_Rollcalls.refreshes, refreshes + 1);
        final panel = find.byType(CampusContextView);
        expect(
          find.descendant(of: panel, matching: find.text('机器学习')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: panel, matching: find.text('软件测试')),
          findsOneWidget,
        );
        expect(find.text('已结束课程'), findsNothing);
        expect(find.text('更晚课程'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('todo-homework-title')));
        await tester.pumpAndSettle();
        expect(find.byType(HomeworkDetailPage), findsOneWidget);
        expect(
          tester
              .widget<HomeworkDetailPage>(find.byType(HomeworkDetailPage))
              .seed
              .id,
          3,
        );
        Navigator.of(tester.element(find.byType(HomeworkDetailPage))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(HomeworkDetailPage), findsNothing);
        expect(tester.takeException(), isNull);
        final trigger = find.descendant(
          of: find.descendant(
            of: sidebar,
            matching: find.byKey(const ValueKey('rollcall-identity-menu')),
          ),
          matching: find.byType(TextButton),
        );
        expect(trigger, findsOneWidget);
        Future<Color> fill() async {
          final rect = tester.getRect(trigger);
          final rendered =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final point = rendered.globalToLocal(
            Offset(rect.right - 25, rect.top + 4),
          );
          return (await tester.runAsync(() async {
            final image = await rendered.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
            final bytes = data!.buffer.asUint8List();
            final color = Color.fromARGB(
              bytes[at + 3],
              bytes[at],
              bytes[at + 1],
              bytes[at + 2],
            );
            image.dispose();
            return color;
          }))!;
        }

        final normal = await fill();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(trigger));
        await tester.pump(const Duration(milliseconds: 80));
        final mid = await fill();
        await tester.pump(const Duration(milliseconds: 300));
        final settled = await fill();
        expect(settled, isNot(normal));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          await fill(),
          settled,
          reason: 'Account hover stays highlighted',
        );
        final low = normal.computeLuminance() < settled.computeLuminance()
            ? normal
            : settled;
        expect(
          mid.computeLuminance(),
          greaterThanOrEqualTo(low.computeLuminance() - .005),
          reason: 'No transient dark flash',
        );
        await mouse.removePointer();
        await tester.pumpAndSettle();
        expect(find.text('历史中最新的未签到课程'), findsOneWidget);
        expect(find.text('未签到'), findsOneWidget);
        expect(
          find.text('工程伦理'),
          findsNothing,
          reason: 'Local submit history is not attendance history',
        );
        final footer = find.byKey(const ValueKey('latest-history-footer'));
        expect(tester.getRect(footer).bottom, closeTo(variant.$2 - 12, 1));
        final record = find.ancestor(
          of: find.text('查看记录'),
          matching: find.byType(AppTextLink),
        );
        final card = find
            .ancestor(
              of: find.text('6428'),
              matching: find.byType(RollcallTaskCard),
            )
            .first;
        expect(
          tester.getRect(record).right,
          closeTo(tester.getRect(card).right, 1),
          reason: 'Record action aligns to the card right edge',
        );
        final loads = attendance.loads;
        final countState = tester.state(find.byType(AttendanceCountRow));
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('作业')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('签到')),
        );
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(AttendanceCountRow)), same(countState));
        expect(
          attendance.loads,
          loads,
          reason:
              'A short tab switch must preserve the attendance refresh timer',
        );
        Future<void> capture(String page) async {
          if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] != '1') return;
          await tester.runAsync(() async {
            final rendered =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: variant.$5);
            final png = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('.tools/desktop-workspace').create(recursive: true);
            await File(
              '.tools/desktop-workspace/$page-${variant.$1.toInt()}-${variant.$3 ? 'dark' : 'light'}-${variant.$4}-dpr${variant.$5}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            rendered.dispose();
          });
        }

        await capture('rollcall');
        final workspace = find.byType(DesktopWorkspace);
        final header = find.descendant(
          of: workspace,
          matching: find.byType(DesktopPageHeader),
        );
        final container = ProviderScope.containerOf(tester.element(workspace));
        final date = find.byKey(const ValueKey('rollcall-header-date'));
        final day = tester.widget<Text>(date);
        final weekday = tester.widget<Text>(
          find.byKey(const ValueKey('rollcall-header-weekday')),
        );
        expect(day.style!.fontSize, greaterThan(weekday.style!.fontSize!));
        expect(
          day.style!.fontSize,
          lessThan(AppTypography.pageTitle.fontSize!),
        );
        final refresh = find.descendant(
          of: header,
          matching: find.byType(AppRefreshButton),
        );
        expect(
          (tester.getCenter(date).dy - tester.getCenter(refresh).dy).abs(),
          lessThan(4),
        );
        for (final label in ['签到记录', '签到设置']) {
          final trigger = find.descendant(
            of: header,
            matching: find.byTooltip(label),
          );
          final sharedAction = find.ancestor(
            of: trigger,
            matching: find.byType(AppIconButton),
          );
          expect(
            sharedAction,
            findsOneWidget,
            reason: 'Actual toolbar actions must use the shared state owner',
          );
          final material = find.descendant(
            of: sharedAction,
            matching: find.byType(Material),
          );
          final side =
              (tester.widget<Material>(material.first).shape as OutlinedBorder)
                  .side;
          expect(
            side.color.a,
            0,
            reason: '$label must not restore a local static frame',
          );
        }
        expect(
          find.descendant(of: header, matching: find.text('签到')),
          findsNothing,
        );
        expect(
          tester
              .widget<ColoredBox>(
                find
                    .descendant(
                      of: find.byType(AppTitleBar),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
              )
              .color,
          AppPalette.of(tester.element(workspace)).sidebar,
        );
        final originalContext = container.read(contextData);
        container.read(contextTime.notifier).state = DateTime(2026, 10, 28, 12);
        await tester.pumpAndSettle();
        for (final title in ['机器学习', '软件测试']) {
          expect(
            find.descendant(of: panel, matching: find.text(title)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: panel, matching: find.text('更晚课程')),
          findsNothing,
        );
        await capture('rollcall-between-classes');
        container.read(contextTime.notifier).state = now;
        await tester.pumpAndSettle();
        for (var reread = 0; reread < 2; reread++) {
          final pending = Completer<CampusCachedData>();
          container.read(pendingContext.notifier).state = pending.future;
          await tester.pump();
          expect(find.byType(CampusContextView), findsOneWidget);
          expect(
            tester
                .widget<CampusContextView>(find.byType(CampusContextView))
                .data,
            same(originalContext),
          );
          expect(
            tester.getSize(header).width,
            lessThan(tester.getSize(workspace).width),
          );
          pending.complete(originalContext);
          await tester.pumpAndSettle();
        }
        final switching = Completer<CampusCachedData>();
        container.read(pendingContext.notifier).state = switching.future;
        await tester.pump();
        container.read(selectedRollcallAccountProvider.notifier).state = 2;
        await tester.pump();
        expect(find.byType(CampusContextView), findsOneWidget);
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('campus-homework-skeleton')),
          findsOneWidget,
        );
        container.read(selectedRollcallAccountProvider.notifier).state = null;
        switching.complete(originalContext);
        await tester.pumpAndSettle();
        container.read(pendingContext.notifier).state = null;
        await tester.pumpAndSettle();
        expect(
          tester.getSize(header).width,
          lessThan(tester.getSize(workspace).width),
        );
        for (final empty in [
          const CampusCachedData(),
          CampusCachedData(
            schedule: AcademicSchedule(
              term: schedule.term,
              monday: schedule.monday,
              fetchedAt: now,
              rows: [schedule.rows.first],
            ),
            hasHomeworkCache: true,
          ),
        ]) {
          container.read(contextData.notifier).state = empty;
          await tester.pumpAndSettle();
          expect(find.byType(CampusContextView), findsNothing);
          expect(tester.getSize(header).width, tester.getSize(workspace).width);
        }
        await capture('rollcall-no-context');
        for (final populated in [
          CampusCachedData(schedule: schedule),
          CampusCachedData(homework: originalContext.homework),
          originalContext,
        ]) {
          container.read(contextData.notifier).state = populated;
          await tester.pumpAndSettle();
          expect(find.byType(CampusContextView), findsOneWidget);
          expect(
            tester.getSize(header).width,
            lessThan(tester.getSize(workspace).width),
          );
        }
        for (final label in ['作业', '课表', '工具', '设置']) {
          await tester.tap(
            find.descendant(of: sidebar, matching: find.text(label)),
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(AppTitleBar),
              matching: find.text('厦大签到'),
            ),
            findsOneWidget,
          );
          final hasHeader = label == '课表';
          expect(
            find.byType(DesktopPageHeader),
            hasHeader ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(DesktopPageHeader),
              matching: find.text(label),
            ),
            findsNothing,
          );
          if (label == '作业') {
            final filters = find.descendant(
              of: find.byType(HomeworkHubPage),
              matching: find.byWidgetPredicate((w) => w is AppSegmentedControl),
            );
            final refresh = find.descendant(
              of: find.byType(HomeworkHubPage),
              matching: find.byType(AppRefreshButton),
            );
            expect(
              tester.getRect(filters).left,
              lessThan(tester.getRect(refresh).left),
            );
          }
          if (label == '课表') {
            final meta = find.byKey(const ValueKey('timetable-header-meta'));
            expect(meta, findsOneWidget);
            expect(
              tester.getRect(meta).right,
              greaterThan(tester.getRect(find.text('学期')).right),
            );
          }
          expect(tester.takeException(), isNull);
          await capture(label);
          if (label == '课表') {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(AdaptiveShell)),
            );
            container.read(selectedRollcallAccountProvider.notifier).state = 2;
            await tester.pumpAndSettle();
            await tester.tap(find.text('学期'));
            await tester.pumpAndSettle();
            expect(find.textContaining('账号二课程'), findsWidgets);
            await capture('课表-学期');
            container.read(selectedRollcallAccountProvider.notifier).state =
                null;
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('签到')),
        );
        await tester.pumpAndSettle();
        expect(find.text('6428'), findsOneWidget);
        for (final label in ['签到设置', '签到记录']) {
          final button = tester.widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == label,
            ),
          );
          expect(button.style?.side?.resolve({}), isNotNull);
        }
        expect(
          tester.getCenter(find.byTooltip('签到设置')).dx,
          greaterThan(tester.getCenter(find.byTooltip('签到记录')).dx),
        );
        expect(find.byTooltip('签到设置'), findsOneWidget);
        expect(find.byTooltip('签到记录'), findsOneWidget);
        expect(find.byTooltip('签到操作'), findsNothing);
        await capture('签到快捷操作');
        await tester.tap(find.text('查看记录'));
        await tester.pumpAndSettle();
        await capture('签到记录');
        final content = find.byKey(const ValueKey('history-course-filter'));
        final filters = find
            .ancestor(of: content, matching: find.byType(Wrap))
            .first;
        final list = find.descendant(
          of: find.byType(HistoryPage),
          matching: find.byType(ListView),
        );
        expect(tester.getRect(list).right, closeTo(variant.$1, 1));
        expect(
          tester.getRect(filters).center.dx,
          closeTo((variant.$1 + tester.getSize(sidebar).width) / 2, 1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      'account switch context skeleton keeps both sections dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 770);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = StateProvider<Future<CampusCachedData>?>((ref) => null);
        final reread = Completer<CampusCachedData>();
        final peer = Completer<CampusCachedData>();
        final boundary = GlobalKey();
        final container = ProviderContainer(
          overrides: [
            secureStoreProvider.overrideWithValue(SecureStore.memory()),
            authControllerProvider.overrideWith((ref) => _Auth()),
            assistServiceProvider.overrideWith((ref) async => _Assist()),
            assistControllerProvider.overrideWith(
              (ref) => AssistController(
                ref,
                bootstrap: false,
                initial: const AssistUiState(
                  ready: true,
                  identities: [
                    AssistIdentity(
                      userId: 2,
                      displayName: '账号二',
                      kind: AssistCredentialKind.session,
                      deviceId: 'fixture-device-2',
                    ),
                  ],
                ),
              ),
            ),
            activeRollcallsProvider.overrideWith(_Rollcalls.new),
            activeRollcallClockProvider.overrideWithValue(() => now),
            rollcallRepositoryForProvider(
              null,
            ).overrideWithValue(_Attendance()),
            rollcallRepositoryForProvider(2).overrideWithValue(_Attendance()),
            currentCourseHistoryProvider.overrideWithValue(const AsyncData([])),
            campusCachedDataProvider.overrideWith((ref) async {
              final scope = ref.watch(selectedRollcallAccountProvider);
              final loading = ref.watch(pending);
              return scope == 2
                  ? peer.future
                  : loading ??
                        CampusCachedData(
                          schedule: schedule,
                          homework: homework,
                        );
            }),
            campusClockProvider.overrideWith((ref) => Stream.value(now)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: const Scaffold(body: RollcallHubPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final panel = find.byType(CampusContextView);
        final header = find.byType(DesktopPageHeader);
        final width = tester.getSize(header).width;
        expect(
          find.descendant(of: panel, matching: find.text('机器学习')),
          findsWidgets,
        );
        container.read(pending.notifier).state = reread.future;
        await tester.pump();
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsNothing,
        );
        expect(
          find.descendant(of: panel, matching: find.text('机器学习')),
          findsWidgets,
        );
        container.read(selectedRollcallAccountProvider.notifier).state = 2;
        await tester.pump();
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('campus-homework-skeleton')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: panel, matching: find.text('机器学习')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('todo-homework-title')), findsNothing);
        expect(find.text('暂无待办事项'), findsNothing);
        expect(tester.getSize(header).width, width);
        if (Platform.environment['CAPTURE_CONTEXT_SKELETON'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(
              'build/context-skeleton-review',
            ).create(recursive: true);
            await File(
              'build/context-skeleton-review/switch-$dark.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        // A late owner reread must not end the target account's loading state.
        reread.complete(
          CampusCachedData(schedule: schedule, homework: homework),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsOneWidget,
        );
        peer.complete(
          CampusCachedData(schedule: peerSchedule, hasHomeworkCache: true),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsNothing,
        );
        expect(
          find.descendant(of: panel, matching: find.text('账号二课程')),
          findsOneWidget,
        );
        expect(find.text('暂无待办事项'), findsOneWidget);
        expect(
          find.descendant(of: panel, matching: find.text('机器学习')),
          findsNothing,
        );
        expect(tester.getSize(header).width, width);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  for (final mobile in [false, true]) {
    testWidgets(
      'loading context masks old courses and homework mobile=$mobile',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: CampusContextView(
                data: CampusCachedData(schedule: schedule, homework: homework),
                now: now,
                loading: true,
                mobile: mobile,
                onTimetable: () {},
                onHomework: () {},
                onOpenHomework: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('campus-course-skeleton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('campus-homework-skeleton')),
          findsOneWidget,
        );
        expect(find.text('今日课程'), findsOneWidget);
        expect(find.text('待办事项'), findsOneWidget);
        expect(find.text('机器学习'), findsNothing);
        expect(find.byKey(const ValueKey('todo-homework-title')), findsNothing);
        expect(find.text('暂无待办事项'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'desktop workspace without context gives the task the full width',
    (tester) async {
      tester.view.physicalSize = const Size(1104, 770);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
          home: const Scaffold(
            body: DesktopWorkspace(title: '签到', child: Text('尚未登录')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DesktopPageHeader)).width, 1104);
      expect(tester.getCenter(find.text('尚未登录')).dx, 552);
    },
  );
  testWidgets(
    'single course timeline reaches below card and metadata icons align',
    (tester) async {
      const longCourseTitle = '非常长的课程名称：软件工程实践与面向对象程序设计专题';
      tester.view.physicalSize = const Size(360, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: CampusContextView(
                data: CampusCachedData(
                  schedule: AcademicSchedule(
                    term: schedule.term,
                    monday: schedule.monday,
                    fetchedAt: now,
                    rows: [
                      AcademicCourseRow.fromJson({
                        ...schedule.rows[1].toJson(),
                        'KCMC': longCourseTitle,
                      }),
                    ],
                  ),
                ),
                now: now,
                onTimetable: () {},
                onHomework: () {},
                onOpenHomework: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final courseTitle = find.text(longCourseTitle);
      expect(tester.widget<Text>(courseTitle).maxLines, 1);
      expect(tester.widget<Text>(courseTitle).overflow, TextOverflow.ellipsis);
      expect(
        tester.renderObject<RenderParagraph>(courseTitle).didExceedMaxLines,
        isTrue,
      );
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('16:10'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('14:30')).dx,
        tester.getTopLeft(find.text('16:10')).dx,
      );
      expect(
        tester.getTopLeft(find.text('教学楼 A301')).dx,
        tester.getTopLeft(courseTitle).dx,
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] == '1') {
        await tester.runAsync(() async {
          final rendered =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.tools/desktop-workspace/timeline-single-dark.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
