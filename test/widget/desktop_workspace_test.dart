import '../fixtures/preview_fonts.dart';
import 'dart:io';
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
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
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
  ],
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
    {...schedule.rows[1], 'KCMC': '账号二课程'},
  ],
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
  Future<void> ensureFresh({bool force = false}) async {}
}

class _Catalog extends CourseCatalogNotifier {
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: now,
    courses: const [CatalogCourse(id: '7', title: '机器学习')],
  );
}

void main() {
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
                campusCachedDataProvider.overrideWith(
                  (ref) async => CampusCachedData(
                    schedule: schedule,
                    homework: homework
                        .where((i) => i.id == 3 || i.id == 6)
                        .toList(),
                    hasHomeworkCache: true,
                  ),
                ),
                campusClockProvider.overrideWith((ref) => Stream.value(now)),
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
        if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] == '1') {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/illustrations/campus_mist.png'),
              tester.element(find.byType(AdaptiveShell)),
            ),
          );
          await tester.pumpAndSettle();
        }
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
        expect(tester.takeException(), isNull);
        final trigger = find.descendant(
          of: sidebar,
          matching: find.byType(AppSelectTrigger),
        );
        final target = find
            .descendant(of: trigger, matching: find.byType(AnimatedContainer))
            .first;
        Color fill() =>
            (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: target,
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .color!;
        final normal = fill();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(trigger));
        await tester.pump(const Duration(milliseconds: 80));
        final mid = fill();
        await tester.pump(const Duration(milliseconds: 300));
        final settled = fill();
        expect(settled, isNot(normal));
        await tester.pump(const Duration(milliseconds: 500));
        expect(fill(), settled, reason: 'Account hover stays highlighted');
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
        final record = find.ancestor(
          of: find.text('查看记录'),
          matching: find.byType(AppTextLink),
        );
        final card = find
            .ancestor(
              of: find.text('6428'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
        expect(
          tester.getRect(record).right,
          closeTo(tester.getRect(card).right, 1),
          reason: 'Record action aligns to the card right edge',
        );
        final loads = attendance.loads;
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('作业')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('签到')),
        );
        await tester.pumpAndSettle();
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
        for (final label in ['作业', '课表', '校园工具', '设置']) {
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
          expect(find.byType(DesktopPageHeader), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(label);
          if (label == '课表') {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(AdaptiveShell)),
            );
            container.read(selectedRollcallAccountProvider.notifier).state = 2;
            await tester.pumpAndSettle();
            expect(find.textContaining('账号二课程'), findsWidgets);
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
        await tester.tap(find.byTooltip('签到操作'));
        await tester.pumpAndSettle();
        expect(find.text('自动检测设置'), findsOneWidget);
        await capture('签到菜单');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        final menuButton = tester.widget<IconButton>(
          find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '签到操作'),
        );
        expect(menuButton.focusNode!.hasFocus, isTrue);
        await tester.tapAt(Offset(variant.$1 * .5, variant.$2 - 50));
        await tester.pumpAndSettle();
        expect(menuButton.focusNode!.hasFocus, isFalse);
        await tester.tap(find.text('查看记录'));
        await tester.pumpAndSettle();
        await capture('签到记录');
        final column = find.byType(AppContentColumn);
        final content = find
            .descendant(of: column, matching: find.byType(ConstrainedBox))
            .first;
        expect(
          tester.getRect(content).center.dx,
          closeTo((variant.$1 + tester.getSize(sidebar).width) / 2, 1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
