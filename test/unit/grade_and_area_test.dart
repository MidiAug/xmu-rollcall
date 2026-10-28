import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';

GradeRecord grade(
  String id,
  String term, {
  double points = 4,
  double credits = 2,
}) => GradeRecord({
  'WID': id,
  'XNXQDM': term,
  'KCM': id,
  'XF': credits,
  'JDF': points,
  'ZCJ': 90,
  'SFYX': '1',
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'GPA weights server points, preserves zero and excludes unknown points',
    () {
      final result = calculateGpa([
        grade('a', '2026-2027-1'),
        grade('b', '2026-2027-1', points: 0, credits: 1),
        const GradeRecord({'WID': 'u', 'XF': 5}),
      ]);
      expect(result.gpa, closeTo(8 / 3, .0001));
      expect(result.credits, 3);
      expect(result.average, 90);
    },
  );
  test(
    'recent refresh replaces complete terms without dropping older courses',
    () {
      final old = [grade('old', '2024-2025-1'), grade('gone', '2026-2027-1')];
      final merged = mergeRecentGrades(
        old,
        [grade('new', '2026-2027-1')],
        {'2026-2027-1'},
      );
      expect(merged.map((r) => r.id), ['old', 'new']);
      final cache = GradeSnapshot(
        at: DateTime(2026, 5, 1),
        term: '20252',
        records: old,
      );
      expect(useRecentGrades(cache, DateTime(2026, 10, 28)), isTrue);
      expect(
        useRecentGrades(
          GradeSnapshot(at: cache.at, term: '20251', records: old),
          DateTime(2026, 10, 28),
        ),
        isFalse,
      );
    },
  );
  test(
    'building wing groups share coordinates while different wings stay separate',
    () {
      expect(coursePlaceGroup('坤銮楼（2号楼）A206'), '坤銮楼（2号楼） A区');
      expect(coursePlaceGroup('坤銮楼（2号楼）A404'), '坤銮楼（2号楼） A区');
      final p = SavedLocation(
        id: 'custom',
        note: '坤銮楼（2号楼） A区',
        latitude: 24.606,
        longitude: 118.31,
        createdAt: DateTime(2026),
      );
      expect(matchCoursePlace('坤銮楼（2号楼）A404', [p])?.id, 'custom');
      expect(matchCoursePlace('坤銮楼（2号楼）B404', [p])?.id, isNot('custom'));
    },
  );
  test(
    'locations migrate only into the owning workspace and persist separately',
    () async {
      final legacy = SavedLocationsController();
      await legacy.ready;
      await legacy.add(note: '旧地点', latitude: 24.6, longitude: 118.3);
      legacy.dispose();
      final owner = SavedLocationsController(ownerId: 1, userId: 1);
      await owner.ready;
      expect(owner.state.single.note, '旧地点');
      final assist = SavedLocationsController(ownerId: 1, userId: 2);
      await assist.ready;
      expect(assist.state, isEmpty);
      await assist.add(note: '协助位置', latitude: 24.6, longitude: 118.3);
      final another = SavedLocationsController(ownerId: 3, userId: 3);
      await another.ready;
      expect(another.state, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(savedLocationsKey(1, 2))!).single['note'],
        '协助位置',
      );
      owner.dispose();
      assist.dispose();
      another.dispose();
    },
  );
  test(
    'per-account detection preference cannot borrow another disabled scope',
    () async {
      final a = DetectionWindowController(ownerId: 1, userId: 1);
      await a.ready;
      await a.save(const DetectionWindow(scheduleBased: true, enabled: false));
      final b = DetectionWindowController(ownerId: 1, userId: 2);
      await b.ready;
      expect((await DetectionWindow.read(uid: 1)).enabled, isFalse);
      expect((await DetectionWindow.read(uid: 2)).enabled, isTrue);
      a.dispose();
      b.dispose();
    },
  );
  test(
    'Sunday course start becomes Monday, manual choice stays independent',
    () {
      final course = CatalogCourse(
        id: 'a',
        title: 'a',
        startDate: DateTime(2026, 9, 6),
      );
      expect(
        teachingMondayFromCourses([course], '20261'),
        DateTime(2026, 9, 7),
      );
      expect(
        CatalogCourse.fromJson(
          course.withRoles(['student']).toJson(),
        ).startDate,
        course.startDate,
      );
      expect(semesterLabel('20261'), '2026年秋季学期');
      expect(semesterLabel('20262'), '2027年春季学期');
    },
  );
}
