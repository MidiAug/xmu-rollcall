import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';

class _Saved extends SavedLocationsController {
  List<SavedLocation> get value => state;
}

class _Courses extends CourseRadarDefaultsController {
  _Courses({super.userId, super.assistUserId});
  Map<String, CourseRadarPref> get value => state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'adding immediately after startup retains stored places and full accuracy',
    () async {
      final old = SavedLocation(
        id: 'old',
        note: 'old room',
        latitude: 24.4,
        longitude: 118.1,
        createdAt: DateTime.utc(2026),
      );
      SharedPreferences.setMockInitialValues({
        'saved_radar_locations': jsonEncode([old.toJson()]),
      });
      final controller = _Saved();
      addTearDown(controller.dispose);
      await controller.add(
        note: 'new room',
        latitude: 24.5,
        longitude: 118.2,
        accuracy: 850,
      );
      expect(controller.value.map((e) => e.note), ['new room', 'old room']);
      final restored = _Saved();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.value.first.accuracy, 850);
      expect(restored.value, hasLength(2));
      await restored.rename(restored.value.first.id, 'renamed');
      await restored.updateCoords(
        restored.value.first.id,
        latitude: 24.6,
        longitude: 118.3,
      );
      await restored.remove('old');
      final again = _Saved();
      addTearDown(again.dispose);
      await again.ready;
      expect(again.value.single.note, 'renamed');
      expect(again.value.single.latitude, 24.6);
    },
  );
  test('invalid saved coordinates do not mutate or persist', () async {
    final controller = _Saved();
    addTearDown(controller.dispose);
    await expectLater(
      controller.add(note: 'bad', latitude: double.nan, longitude: 118.1),
      throwsArgumentError,
    );
    expect(controller.value, isEmpty);
  });
  test(
    'concurrent course writes retain preexisting and new courses after restart',
    () async {
      SharedPreferences.setMockInitialValues({
        'course_radar_defaults_1': jsonEncode({
          'id:old': const CourseRadarPref(
            courseTitle: 'old',
            courseId: 'old',
            latitude: 24.4,
            longitude: 118.1,
          ).toJson(),
        }),
      });
      final controller = _Courses(userId: 1);
      addTearDown(controller.dispose);
      await Future.wait([
        for (final id in ['a', 'b'])
          controller.rememberSuccess(
            courseTitle: 'same title',
            courseId: id,
            latitude: 24.5,
            longitude: 118.2,
            accuracy: 850,
            obtainedVia: RadarObtainedVia.device,
            meetingKey: 'monday',
          ),
      ]);
      final restored = _Courses(userId: 1);
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.value, hasLength(3));
      expect(
        restored.forCourse(courseId: 'a', meetingKey: 'monday')?.accuracy,
        850,
      );
      expect(
        restored.forCourse(courseId: 'b', meetingKey: 'monday')?.courseId,
        'b',
      );
    },
  );
  test(
    'owner, assist identity and another owner keep course positions isolated',
    () async {
      final owner = _Courses(userId: 1);
      final assist = _Courses(userId: 1, assistUserId: 2);
      final other = _Courses(userId: 3, assistUserId: 2);
      addTearDown(owner.dispose);
      addTearDown(assist.dispose);
      addTearDown(other.dispose);
      await owner.rememberSuccess(
        courseTitle: 'course',
        courseId: '1',
        latitude: 24.4,
        longitude: 118.1,
        obtainedVia: RadarObtainedVia.map,
        meetingKey: 'monday',
      );
      await assist.rememberSuccess(
        courseTitle: 'course',
        courseId: '1',
        latitude: 24.5,
        longitude: 118.2,
        obtainedVia: RadarObtainedVia.map,
        meetingKey: 'monday',
      );
      await other.ready;
      expect(
        owner.forCourse(courseId: '1', meetingKey: 'monday')?.latitude,
        24.4,
      );
      expect(
        assist.forCourse(courseId: '1', meetingKey: 'monday')?.latitude,
        24.5,
      );
      expect(other.forCourse(courseId: '1', meetingKey: 'monday'), isNull);
    },
  );
  test(
    'disposing while initial load waits never updates disposed controllers',
    () async {
      final saved = _Saved();
      final courses = _Courses(userId: 1);
      saved.dispose();
      courses.dispose();
      await Future.wait([saved.ready, courses.ready]);
    },
  );
}
