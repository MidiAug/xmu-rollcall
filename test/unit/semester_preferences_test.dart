import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/schedule_detection.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';

AcademicSchedule semesterFixture() => AcademicSchedule(
  term: '20261',
  monday: DateTime(2026, 9, 7),
  fetchedAt: DateTime(2026, 10, 27),
  rows: [
    {
      'KCDM': 'C',
      'KCMC': '测试课程',
      'BJDM': 'A',
      'XQ': 1,
      'ZCBH': '1010',
      'KSJCDM': 3,
      'JSJCDM': 4,
      'startMinute': 610,
      'endMinute': 710,
      'JASMC': 'A101',
    },
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Monday validation, account and term isolation, clear-cache preservation and reset',
    () async {
      await expectLater(
        SemesterPreferences.save(1, '20261', DateTime(2026, 9, 8)),
        throwsFormatException,
      );
      await SemesterPreferences.save(1, '20261', DateTime(2026, 9, 14, 14));
      expect(await SemesterPreferences.read(1, '20261'), DateTime(2026, 9, 14));
      expect(await SemesterPreferences.read(2, '20261'), isNull);
      expect(await SemesterPreferences.read(1, '20262'), isNull);
      await JsonDiskCache.writeList('sample', []);
      await JsonDiskCache.clearAll();
      expect(await SemesterPreferences.read(1, '20261'), DateTime(2026, 9, 14));
      await SemesterPreferences.save(1, '20261', null);
      expect(await SemesterPreferences.read(1, '20261'), isNull);
    },
  );
  test(
    'explicit user start survives sync and takes priority over maintained calendar',
    () async {
      final source = semesterFixture();
      await AcademicScheduleStore.write(1, source);
      await SemesterPreferences.save(1, source.term, DateTime(2026, 9, 14));
      expect(
        (await AcademicScheduleStore.read(1))!.monday,
        DateTime(2026, 9, 14),
      );
      expect(
        (await AcademicScheduleStore.read(1, useUserStart: false))!.monday,
        DateTime(2026, 9, 7),
      );
      await AcademicScheduleStore.write(
        1,
        semesterFixture(),
      ); // Later remote sync.
      final effective = (await AcademicScheduleStore.read(1))!;
      expect(effective.monday, DateTime(2026, 9, 14));
      expect(effective.allTables[1]!.single.dates, {
        '2026-09-14',
        '2026-09-28',
      });
      expect(source.monday, DateTime(2026, 9, 7));
      await SemesterPreferences.save(1, source.term, null);
      expect(
        (await AcademicScheduleStore.read(1))!.monday,
        academicMondays['20261'],
      );
    },
  );
  test(
    'foreground, Android reload and history use the same changed calendar',
    () async {
      await AcademicScheduleStore.write(1, semesterFixture());
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime.now(),
          rolesResolved: true,
          courses: const [
            CatalogCourse(id: 'tron', title: '测试课程', courseCode: 'C'),
          ],
        ),
      );
      await SemesterPreferences.save(1, '20261', DateTime(2026, 9, 14));
      final at = DateTime(2026, 9, 14, 10);
      final foreground = await readScheduleDetectionWindow(1, at: at);
      final background = await readScheduleDetectionWindow(
        1,
        reload: true,
        at: at,
      );
      expect(foreground.allows(at), isTrue);
      expect(background.allows(at), isTrue);
      expect(foreground.allows(DateTime(2026, 9, 21, 10)), isFalse);
      final catalog = (await readAcademicCatalog(1))!;
      final candidates = selectHistoryCandidates(
        courseTitles: catalog.attendanceTitlesById,
        disks: const {},
        seenInProgressCourseIds: const {},
        timetablesByCourse: catalog.timetablesByCourse,
        now: at,
        manualRefresh: true,
      );
      expect(candidates.single.reason, 'scheduled_window');
      final through = DateTime(2026, 9, 14, 12, 30);
      final snapshots = {
        'tron': CourseRollcallsSnapshot(
          courseId: 'tron',
          courseTitle: '测试课程',
          lastSuccessfulFetch: through,
          checkedThrough: through,
        ),
      };
      expect(
        selectHistoryCandidates(
          courseTitles: catalog.attendanceTitlesById,
          disks: snapshots,
          seenInProgressCourseIds: const {},
          timetablesByCourse: catalog.timetablesByCourse,
          now: DateTime(2026, 9, 21, 10),
          manualRefresh: true,
        ),
        isEmpty,
      );
      await SemesterPreferences.save(1, '20261', null);
      final restored = await readScheduleDetectionWindow(
        1,
        reload: true,
        at: at,
      );
      expect(restored.allows(at), isFalse);
      expect(restored.allows(DateTime(2026, 9, 21, 10)), isTrue);
    },
  );
  test('stale account guard prevents writing', () async {
    await expectLater(
      SemesterPreferences.save(
        1,
        '20261',
        DateTime(2026, 9, 14),
        requireCurrent: () => throw StateError('changed account'),
      ),
      throwsStateError,
    );
    expect(await SemesterPreferences.read(1, '20261'), isNull);
  });
  test(
    'unknown default remains distinct from user date and can later adopt maintained calendar',
    () async {
      final source = AcademicSchedule(
        term: '20271',
        monday: DateTime(2027, 9, 6),
        anchorFromUser: true,
        fetchedAt: DateTime(2027, 9, 6),
        rows: [],
      );
      await AcademicScheduleStore.write(1, source);
      expect(await AcademicScheduleStore.read(1), isNull);
      await SemesterPreferences.save(1, '20271', DateTime(2027, 9, 13));
      expect(
        (await AcademicScheduleStore.read(1))!.monday,
        DateTime(2027, 9, 13),
      );
      academicMondays['20271'] = DateTime(2027, 9, 6);
      try {
        expect(
          (await AcademicScheduleStore.read(1))!.monday,
          DateTime(2027, 9, 13),
        );
        await SemesterPreferences.save(1, '20271', null);
        expect(
          (await AcademicScheduleStore.read(1))!.monday,
          DateTime(2027, 9, 6),
        );
      } finally {
        academicMondays.remove('20271');
      }
    },
  );
  test(
    'week labels use the chosen Monday without exposing request details',
    () {
      final info = SemesterInfo(
        term: '20261',
        start: DateTime(2026, 9, 14),
        manual: true,
      );
      expect(info.weekLabel(DateTime(2026, 9, 13)), '尚未开课');
      expect(info.weekLabel(DateTime(2026, 9, 14)), '第1周');
      expect(info.weekLabel(DateTime(2026, 9, 21)), '第2周');
      expect(currentSemester(DateTime(2027, 9, 7)), '20271');
    },
  );
}
