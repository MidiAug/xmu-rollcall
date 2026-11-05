import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/features/schedule/academic_timetable_reader.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

class _Catalog extends CourseCatalogNotifier {
  _Catalog(this.snapshot);
  final CourseCatalogSnapshot snapshot;
  int requests = 0;
  @override
  Future<CourseCatalogSnapshot?> build() async => snapshot;
  @override
  Future<void> refresh() async {
    requests++;
  }
}

class _PendingReader extends AcademicTimetableReader {
  _PendingReader(SecureStore store, this.result)
    : super(AcademicSession(store: store));
  final Completer<AcademicSchedule> result;
  int calls = 0;
  @override
  Future<AcademicSchedule> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    DateTime? at,
  }) {
    calls++;
    return result.future;
  }
}

class _CountingSync extends AcademicSync {
  _CountingSync(super.store, {super.resolveIdentity});
  int calls = 0;
  @override
  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) {
    calls++;
    return super.sync(
      uid,
      sso: sso,
      username: username,
      password: password,
      force: force,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final font = Platform.environment['SETTINGS_UI_FONT'];
    if (font != null) {
      await (FontLoader('MaterialIcons')..addFont(
            File(
              Platform.environment['SETTINGS_UI_ICONS']!,
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader('ScheduleUi')..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
    }
  });
  test(
    'reopening a fresh timetable never enters sync or resolves credentials',
    () async {
      final saved = AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime.now(),
        rows: [],
      );
      await AcademicScheduleStore.write(1, saved);
      final store = SecureStore.memory({SecureStore.keyUserId: '1'});
      var identities = 0;
      late _CountingSync sync;
      final container = ProviderContainer(
        overrides: [
          academicSyncProvider.overrideWith((ref) {
            sync = _CountingSync(
              store,
              resolveIdentity: (_) async {
                identities++;
                throw StateError('fresh cache must bypass identity');
              },
            );
            ref.onDispose(sync.dispose);
            return sync;
          }),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        academicTimetableProvider(1),
        (_, _) {},
      );
      addTearDown(listener.close);
      for (var i = 0; i < 3; i++) {
        if (i > 0) container.invalidate(academicTimetableProvider(1));
        final result = await container.read(
          academicTimetableProvider(1).future,
        );
        expect(result.schedule?.term, '20261');
        expect(result.needsLogin, false);
        expect(result.message, isNull);
      }
      expect(identities, 0);
      expect(sync.calls, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('academic_attempt_1'), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'low frequency timetable update lives in data settings on $platform',
      (tester) async {
        tester.view.physicalSize = Size(
          platform == TargetPlatform.android ? 384 : 960,
          844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: DateTime.now(),
          rows: [],
        );
        await AcademicScheduleStore.write(1, saved);
        final pending = Completer<AcademicSchedule>();
        final store = SecureStore.memory({SecureStore.keyUserId: '1'});
        final reader = _PendingReader(store, pending);
        final container = ProviderContainer(
          overrides: [
            secureStoreProvider.overrideWithValue(store),
            authControllerProvider.overrideWith((ref) => _Auth()),
            academicSyncProvider.overrideWith((ref) {
              final sync = AcademicSync(
                store,
                createReader: (_) => reader,
                resolveIdentity: (_) async => AcademicIdentity(
                  username: 'fixture-student',
                  password: 'fixture-only',
                  isCurrent: () async => true,
                ),
                onUpdated: (_) =>
                    ref.read(academicRevisionProvider.notifier).state++,
              );
              ref.onDispose(sync.dispose);
              return sync;
            }),
          ],
        );
        addTearDown(container.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (_, child) =>
                  RepaintBoundary(key: capture, child: child!),
              theme: AppTheme.light().copyWith(platform: platform),
              home: const CoursesPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(reader.calls, 0);
        expect(
          find.byKey(const ValueKey('academic-timetable-refresh')),
          findsNothing,
        );
        Navigator.of(tester.element(find.byType(CoursesPage))).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsDataPage()),
        );
        await tester.pumpAndSettle();
        expect(
          reader.calls,
          0,
          reason: 'Opening data settings only reads cached metadata',
        );
        expect(find.text('教务课表'), findsOneWidget);
        if (Platform.environment['CAPTURE_ACADEMIC_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/timetable-data-settings',
            ).create(recursive: true);
            await File(
              'build/timetable-data-settings/${platform.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.tap(
          find.byKey(const ValueKey('academic-timetable-update')),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(reader.calls, 1);
        pending.complete(
          AcademicSchedule(
            term: saved.term,
            monday: saved.monday,
            fetchedAt: DateTime.now(),
            rows: saved.rows,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('课表已更新'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('academic-timetable-update')),
        );
        await tester.pumpAndSettle();
        expect(
          reader.calls,
          1,
          reason: 'Manual refresh still obeys the shared 15 second cooldown',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'previous-term timetable remains visible while new-term sync waits',
    (tester) async {
      final now = DateTime.now();
      AcademicSchedule snapshot(
        String title,
        DateTime fetched, {
        String term = '20261',
      }) => AcademicSchedule(
        term: term,
        monday: term == '20261' ? DateTime(2026, 9, 7) : DateTime(2026, 6, 29),
        fetchedAt: fetched,
        rows: [
          AcademicCourseRow.fromJson({
            'KCDM': 'cache',
            'KCMC': title,
            'BJDM': 'A',
            'XQ': 1,
            'KSJCDM': 3,
            'JSJCDM': 4,
            'startMinute': 610,
            'endMinute': 710,
            'JASMC': '学武楼A404',
            'ZCBH': '11111111111111111111111111111111',
          }),
        ],
      );
      await AcademicScheduleStore.write(
        1,
        snapshot('已缓存课程', DateTime(2026, 8, 1), term: '20253'),
      );
      final store = SecureStore.memory({SecureStore.keyUserId: '1'});
      final pending = Completer<AcademicSchedule>();
      final reader = _PendingReader(store, pending);
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          authControllerProvider.overrideWith((ref) => _Auth()),
          academicSyncProvider.overrideWith((ref) {
            final sync = AcademicSync(
              store,
              createReader: (_) => reader,
              resolveIdentity: (_) async => AcademicIdentity(
                username: '2099000000001',
                password: 'fixture-only',
                isCurrent: () async => true,
              ),
              onUpdated: (_) =>
                  ref.read(academicRevisionProvider.notifier).state++,
            );
            ref.onDispose(sync.dispose);
            return sync;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const CoursesPage(),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(reader.calls, 1);
      expect(pending.isCompleted, false);
      expect(find.byType(TimetableGridView), findsOneWidget);
      expect(container.read(academicTimetableProvider(1)).isLoading, true);
      final cached = await container.read(
        academicCachedScheduleProvider(1).future,
      );
      final courseList = container.read(
        academicDisplayCoursesProvider(cached!),
      );
      await tester.tap(find.text('学期'));
      await tester.pumpAndSettle();
      expect(
        container.read(academicDisplayCoursesProvider(cached)),
        same(courseList),
      );
      expect(reader.calls, 1);
      pending.complete(snapshot('更新后的课程', now));
      await tester.pumpAndSettle();
      expect(
        container
            .read(academicTimetableProvider(1))
            .valueOrNull
            ?.schedule
            ?.rows
            .single
            .courseName,
        '更新后的课程',
      );
      expect(reader.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [384.0, 960.0]) {
    testWidgets(
      'week/term toggle is local and excludes off-week meetings at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
        CatalogCourse course(String id, int offset) => CatalogCourse(
          id: id,
          title: offset == 0 ? '计算机网络' : '人工智能导论',
          academicMatched: true,
          timetables: {
            1: [
              TimetableSlot(
                sequence: 3,
                endSequence: 4,
                start: DateTime(2000, 1, 3, 10, 10),
                end: DateTime(2000, 1, 3, 11, 50),
                classroom: '教学楼 A101',
                weekLabel: offset == 0 ? '第1、3周' : '第2、4周',
                dates: {
                  TimetableSlot.dateKey(monday.add(Duration(days: offset))),
                },
              ),
            ],
          },
        );
        final academicCourses = [course('current', 0), course('next', 7)];
        final catalog = _Catalog(
          CourseCatalogSnapshot(
            fetchedAt: now,
            courses: [
              ...academicCourses,
              CatalogCourse(
                id: 'ta',
                title: '助教课程不得显示',
                roles: const ['instructor_assistant'],
                timetables: course('ta', 0).timetables,
              ),
              CatalogCourse(
                id: 'teacher',
                title: '教师课程不得显示',
                roles: const ['instructor'],
                timetables: course('teacher', 0).timetables,
              ),
            ],
          ),
        );
        final boundary = GlobalKey();
        var theme = AppTheme.light();
        if (Platform.environment['SETTINGS_UI_FONT'] != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'ScheduleUi'),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.merge(
                TextButton.styleFrom(
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'ScheduleUi',
                  ),
                ),
              ),
            ),
          );
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                courseCatalogProvider.overrideWith(() => catalog),
                academicTimetableProvider(1).overrideWith(
                  (ref) async => AcademicTimetableState(
                    schedule: AcademicSchedule(
                      term: '20261',
                      monday: monday,
                      fetchedAt: now,
                      rows: [
                        for (final (i, c) in academicCourses.indexed)
                          {
                            'KCDM': c.id,
                            'BJDM': 'A',
                            'KCMC': c.title,
                            'XQ': 1,
                            'KSJCDM': 3,
                            'JSJCDM': 4,
                            'startMinute': 610,
                            'endMinute': 710,
                            'JASMC': '教学楼 A101',
                            'ZCBH': i == 0 ? '10' : '01',
                          },
                      ].map(AcademicCourseRow.fromJson).toList(),
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: const CoursesPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TimetableGridView>(find.byType(TimetableGridView))
              .courses
              .map((c) => c.id),
          ['academic:current/A'],
        );
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(find.text('补全安排'), findsNothing);
        expect(find.text('关联课程'), findsNothing);
        await tester.tap(find.text('学期'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TimetableGridView>(find.byType(TimetableGridView))
              .courses,
          hasLength(2),
        );
        expect(catalog.requests, 0);
        expect(find.text('助教课程不得显示'), findsNothing);
        expect(find.text('教师课程不得显示'), findsNothing);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_ACADEMIC_UI'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('.tools/academic-ui').create(recursive: true);
            await File(
              '.tools/academic-ui/term-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
