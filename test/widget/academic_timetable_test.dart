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
