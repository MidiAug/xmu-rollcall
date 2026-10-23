import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'explicit course setup persists without a successful network submission',
    () async {
      final controller = CourseRadarDefaultsController(
        userId: 1,
        assistUserId: 2,
      );
      addTearDown(controller.dispose);
      await controller.configureForCourse(
        courseId: '7',
        courseTitle: 'same name',
        selection: const RadarGeoSelection(
          latitude: 24.5,
          longitude: 118.2,
          accuracy: 180,
          obtainedVia: RadarObtainedVia.map,
        ),
      );
      final pref = await readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: 2,
        courseId: '7',
      );
      expect(pref!.userConfigured, true);
      expect(pref.accuracy, 180);
      expect(
        selectionFromCoursePref(pref, []).filledFrom,
        RadarFilledFrom.configured,
      );
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
        ),
        isNull,
      );
      expect(
        await readAutomaticRadarLocation(
          ownerId: 3,
          assistUserId: 2,
          courseId: '7',
        ),
        isNull,
      );
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: 2,
          courseId: '8',
        ),
        isNull,
      );
    },
  );
  test(
    'automatic read rejects title fallback, mismatched ids and damaged coordinates',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final pref = const CourseRadarPref(
        courseTitle: 'same name',
        courseId: '8',
        latitude: 24.5,
        longitude: 118.2,
      ).toJson();
      for (final raw in [
        {'t:same name': pref},
        {'id:7': pref},
        {
          'id:7': {...pref, 'courseId': '7', 'latitude': 91},
        },
        {
          'id:7': {...pref, 'courseId': '7', 'accuracy': 0},
        },
      ]) {
        await prefs.setString('course_radar_defaults_1', jsonEncode(raw));
        expect(
          await readAutomaticRadarLocation(
            ownerId: 1,
            assistUserId: null,
            courseId: '7',
          ),
          isNull,
        );
      }
      await prefs.setString(
        'course_radar_defaults_1',
        jsonEncode({
          'id:7': {...pref, 'courseId': '7'},
        }),
      );
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
        ),
        isNotNull,
      );
      await prefs.remove('course_radar_defaults_1');
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
        ),
        isNull,
      );
    },
  );
}
