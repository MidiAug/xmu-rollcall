import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/location_validation_store.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('classroom groups merge only the same building and wing', () {
    final scope = ProviderContainer(
      overrides: [
        campusCachedDataProvider.overrideWith(
          (ref) async => const CampusCachedData(),
        ),
        courseRoomsProvider.overrideWithValue([
          '新教学楼A101',
          '新教学楼 A102',
          '新教学楼B201、B202',
          '新教学楼B203',
          '文宣楼B404、C405',
        ]),
      ],
    );
    addTearDown(scope.dispose);
    expect(coursePlaceNames('新教学楼（5号楼）A101、A102'), ['新教学楼（5号楼） A区']);
    final groups = scope.read(coursePlaceGroupsProvider);
    expect(groups.length, 4);
    expect(groups.singleWhere((g) => g.name == '新教学楼 A区').rooms.length, 2);
    expect(groups.singleWhere((g) => g.name == '新教学楼 B区').rooms.length, 2);
    expect(scope.read(unmatchedRoomsProvider).length, 2);
  });
  test('only explicit server location rejection is a correction error', () {
    for (final result in [
      const AnswerResult(ok: false, status: 400, raw: {'code': 'out_of_range'}),
      const AnswerResult(ok: false, status: 422, raw: {'distance': 220}),
      const AnswerResult(ok: false, status: 400, message: '不在签到范围内'),
    ]) {
      expect(result.isLocationRejected, isTrue);
    }
    for (final result in [
      const AnswerResult(ok: true, raw: {'code': 'out_of_range'}),
      const AnswerResult(ok: false, status: 500, message: 'invalid location'),
      const AnswerResult(ok: false, status: 401, message: 'invalid location'),
      const AnswerResult(ok: false, status: 429),
      const AnswerResult(ok: false, status: 400, message: '签到已结束'),
      const AnswerResult(ok: false, status: 403, message: '无权限'),
      const AnswerResult(ok: false, status: 400, message: '签到不在有效时间范围内'),
      const AnswerResult(ok: false, status: 403, message: '不在课程权限范围内'),
      const AnswerResult(ok: false, status: 400, message: '位置验证超时'),
    ]) {
      expect(result.isLocationRejected, isFalse);
    }
  });
  test(
    'rejected point is scoped, blocked, and corrected without new authorization',
    () async {
      final controller = SavedLocationsController(ownerId: 1, userId: 2);
      addTearDown(controller.dispose);
      final original = await controller.add(
        note: '新教学楼 A区',
        latitude: 24.605,
        longitude: 118.31,
      );
      final point = CourseRadarPref(
        courseId: '7',
        courseTitle: '课程一',
        meetingKey: 'm',
        placeId: original.id,
        labelSnapshot: original.note,
        latitude: original.latitude,
        longitude: original.longitude,
        userConfigured: true,
      );
      final prefs = await SharedPreferences.getInstance();
      final key = courseRadarPreferencesKey(1, 2)!;
      await prefs.setString(key, jsonEncode({'id:7': point.toJson()}));
      await recordLocationIssue(1, 2, point);
      expect(await readLocationIssues(1, 1), isEmpty);
      expect(await readLocationIssues(9, 2), isEmpty);
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: 2,
          courseId: '7',
          meetingKey: 'm',
        ),
        isNull,
      );
      await expectLater(
        updateRadarPlaceBindings(
          1,
          2,
          await readLocationIssues(1, 2),
          original,
        ),
        throwsArgumentError,
      );
      expect(await readLocationIssues(1, 2), isNotEmpty);
      await controller.updateCoords(
        original.id,
        latitude: 24.606,
        longitude: 118.312,
      );
      final corrected = controller.state.single;
      await updateRadarPlaceBindings(
        1,
        2,
        await readLocationIssues(1, 2),
        corrected,
      );
      expect(await readLocationIssues(1, 2), isEmpty);
      final saved = await readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: 2,
        courseId: '7',
        meetingKey: 'm',
      );
      expect(saved!.latitude, corrected.latitude);
      expect(saved.placeId, corrected.id);
      expect(saved.userConfigured, isTrue);
      expect((jsonDecode(prefs.getString(key)!) as Map).keys, ['id:7']);
      expect(prefs.getString(courseRadarPreferencesKey(1, null)!), isNull);
    },
  );
  test(
    'manual rejection uses the exact cached classroom and never another wing of that course',
    () async {
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026),
          courses: const [
            CatalogCourse(id: '7', title: '课程', location: '新教学楼A101'),
          ],
        ),
      );
      const point = CourseRadarPref(
        courseId: '7',
        courseTitle: '课程',
        latitude: 24.6,
        longitude: 118.3,
      );
      await recordLocationIssue(1, 1, point);
      final issue = (await readLocationIssues(1, 1)).single;
      expect(issue.point.labelSnapshot, '新教学楼 A区');
      expect(issue.concerns('新教学楼 A区', ['课程']), isTrue);
      expect(issue.concerns('新教学楼 B区', ['课程']), isFalse);
      expect(issue.matches(point), isTrue);
    },
  );
  test(
    'updating a named binding never adds authorization or another course',
    () async {
      const point = CourseRadarPref(
        courseId: '7',
        courseTitle: '课程',
        meetingKey: 'm',
        placeId: 'old',
        labelSnapshot: '新教学楼 A区',
        latitude: 24.6,
        longitude: 118.3,
      );
      final prefs = await SharedPreferences.getInstance();
      final key = courseRadarPreferencesKey(1, null)!;
      await prefs.setString(key, jsonEncode({'id:7': point.toJson()}));
      await updateRadarPlaceBindings(
        1,
        null,
        [],
        SavedLocation(
          id: 'new',
          note: '新教学楼 A区',
          latitude: 24.61,
          longitude: 118.31,
          createdAt: DateTime(2026),
        ),
      );
      final json = jsonDecode(prefs.getString(key)!) as Map;
      expect(json.keys, ['id:7']);
      expect(json['id:7']['latitude'], 24.61);
      expect(json['id:7']['userConfigured'], isFalse);
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
          meetingKey: 'm',
        ),
        isNull,
      );
    },
  );
  test('a stale failed response never overwrites a newer binding', () async {
    final old = CourseRadarPref(
      courseId: '7',
      courseTitle: '课程',
      meetingKey: 'm',
      latitude: 24.6,
      longitude: 118.3,
      userConfigured: true,
    );
    final newer = {...old.toJson(), 'latitude': 24.61, 'userConfigured': false};
    final prefs = await SharedPreferences.getInstance();
    final key = courseRadarPreferencesKey(1, null)!;
    await prefs.setString(key, jsonEncode({'id:7': newer}));
    await recordLocationIssue(1, 1, old);
    await updateRadarPlaceBindings(
      1,
      null,
      await readLocationIssues(1, 1),
      SavedLocation(
        id: 'new',
        note: '课表地点',
        latitude: 24.62,
        longitude: 118.3,
        createdAt: DateTime(2026),
      ),
    );
    final json = (jsonDecode(prefs.getString(key)!) as Map)['id:7'] as Map;
    expect(json['latitude'], 24.61);
    expect(json['userConfigured'], isFalse);
  });
}
