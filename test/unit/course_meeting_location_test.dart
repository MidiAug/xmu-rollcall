import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

const monday = '1:1-3:480-630';
const wednesday = '3:5-6:870-970';
const friday = '5:1-2:480-580';
const meetings = [
  CourseMeeting(
    weekday: 1,
    first: 1,
    last: 3,
    startMinutes: 480,
    endMinutes: 630,
  ),
  CourseMeeting(
    weekday: 3,
    first: 5,
    last: 6,
    startMinutes: 870,
    endMinutes: 970,
  ),
];

RadarGeoSelection point(double lat) => RadarGeoSelection(
  latitude: lat,
  longitude: 118.2,
  accuracy: 180,
  obtainedVia: RadarObtainedVia.map,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'first setup shares a default; later setup affects only selected meetings across restart',
    () async {
      final controller = CourseRadarDefaultsController(userId: 1);
      addTearDown(controller.dispose);
      Future<void> configure(double lat, List<String> keys) =>
          controller.configureForCourse(
            courseId: '7',
            courseTitle: '课程',
            selection: point(lat),
            meetingKeys: keys,
          );
      await configure(24.4, [monday]);
      expect(
        controller.forCourse(courseId: '7', meetingKey: wednesday)!.latitude,
        24.4,
      );
      expect(
        controller.forCourse(courseId: '7', meetingKey: wednesday)!.meetingKey,
        isEmpty,
      );
      await configure(24.5, [wednesday]);
      expect(
        controller.forCourse(courseId: '7', meetingKey: monday)!.latitude,
        24.4,
      );
      expect(
        controller.forCourse(courseId: '7', meetingKey: wednesday)!.latitude,
        24.5,
      );
      expect(
        controller.forCourse(courseId: '7', meetingKey: friday)!.latitude,
        24.4,
      );
      await configure(24.6, [monday, friday]);
      final restored = CourseRadarDefaultsController(userId: 1);
      addTearDown(restored.dispose);
      await restored.ready;
      expect(
        restored.forCourse(courseId: '7', meetingKey: monday)!.latitude,
        24.6,
      );
      expect(
        restored.forCourse(courseId: '7', meetingKey: friday)!.latitude,
        24.6,
      );
      expect(
        restored.forCourse(courseId: '7', meetingKey: wednesday)!.latitude,
        24.5,
      );
      expect(
        (await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
          meetingKey: wednesday,
        ))!.latitude,
        24.5,
      );
      expect(
        await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: 2,
          courseId: '7',
          meetingKey: monday,
        ),
        isNull,
      );
    },
  );

  test(
    'success stays in its meeting; late responses cannot overwrite a newer choice',
    () async {
      CourseRadarPref success(String key, double lat, int stamp) =>
          CourseRadarPref(
            courseTitle: '课程',
            courseId: '7',
            meetingKey: key,
            latitude: lat,
            longitude: 118.2,
            updatedAtMicros: stamp,
          );
      await persistMeetingRadarPoint(1, null, success(monday, 24.4, 100));
      Future<CourseRadarPref?> read(String key) => readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: null,
        courseId: '7',
        meetingKey: key,
      );
      expect((await read(monday))!.latitude, 24.4);
      expect(await read(wednesday), isNull);
      await persistMeetingRadarPoint(
        1,
        null,
        success(monday, 24.5, 300).forMeeting(monday, configured: true),
      );
      await persistMeetingRadarPoint(1, null, success(monday, 24.3, 200));
      expect((await read(monday))!.latitude, 24.5);
      await persistMeetingRadarPoint(1, null, success(monday, 24.6, 400));
      await persistMeetingRadarPoint(1, null, success(monday, 24.2, 150));
      expect((await read(monday))!.latitude, 24.6);
      final restored = CourseRadarDefaultsController(userId: 1);
      addTearDown(restored.dispose);
      await restored.ready;
      expect(
        restored.forCourse(courseId: '7', meetingKey: monday)!.latitude,
        24.6,
      );
      expect(restored.forCourse(courseId: '7', meetingKey: wednesday), isNull);
      await restored.rememberSuccess(
        courseTitle: 'unknown meeting',
        courseId: '8',
        latitude: 24.4,
        longitude: 118.2,
        obtainedVia: RadarObtainedVia.map,
      );
      expect(restored.forCourse(courseId: '8'), isNull);
    },
  );

  test(
    'current meeting resolves local multi-period schedules in the right account and anchors an active event',
    () async {
      await CourseCatalogStore.write(
        2,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 26),
          rolesResolved: true,
          courses: const [CatalogCourse(id: '7', title: '课程')],
        ),
      );
      await CourseScheduleStore.write(2, '7', meetings);
      Future<String?> resolve(int? assist, DateTime at) => resolveRadarMeeting(
        ownerId: 1,
        assistUserId: assist,
        courseId: '7',
        at: at,
      );
      expect(await resolve(2, DateTime(2026, 10, 26, 9)), monday);
      expect(await resolve(2, DateTime(2026, 10, 28, 15)), wednesday);
      expect(await resolve(2, DateTime(2026, 10, 26, 15)), isNull);
      expect(await resolve(null, DateTime(2026, 10, 26, 9)), isNull);
      final controller = CourseRadarDefaultsController(
        userId: 1,
        assistUserId: 2,
      );
      addTearDown(controller.dispose);
      await controller.configureForCourse(
        courseId: '7',
        courseTitle: '课程',
        selection: point(24.4),
        meetingKeys: [monday],
      );
      await controller.configureForCourse(
        courseId: '7',
        courseTitle: '课程',
        selection: point(24.5),
        meetingKeys: [wednesday],
      );
      var now = DateTime(2026, 10, 26, 9);
      final reader = createAutomaticRadarLocationReader(
        ownerId: 1,
        assistUserId: 2,
        now: () => now,
      );
      RollcallItem item(int id) => RollcallItem(
        rollcallId: id,
        courseTitle: '课程',
        createdByName: '',
        type: RollcallType.radar,
        status: 'on_call',
        rollcallStatus: 'on_call',
        isExpired: false,
        scored: false,
        raw: {'course_id': 7},
      );
      expect((await reader(item(10)))!.meetingKey, monday);
      now = DateTime(2026, 10, 28, 15);
      expect((await reader(item(10)))!.meetingKey, monday);
      expect((await reader(item(11)))!.meetingKey, wednesday);
      await CourseScheduleStore.write(2, '7', [meetings.last]);
      expect(await resolve(2, DateTime(2026, 10, 26, 9)), isNull);
    },
  );
}
