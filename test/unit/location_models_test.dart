import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/rollcall/number_code.dart';

void main() {
  test('SavedLocation round-trip', () {
    final loc = SavedLocation(
      id: 'a',
      note: '海韵 A',
      latitude: 24.44,
      longitude: 118.09,
      accuracy: 30,
      createdAt: DateTime.utc(2026, 9, 15),
    );
    final again = SavedLocation.fromJson(loc.toJson());
    expect(again.note, '海韵 A');
    expect(again.latitude, 24.44);
    expect(again.longitude, 118.09);
  });

  test('CourseRadarPref round-trip keeps placeId', () {
    final d = CourseRadarPref(
      courseTitle: '测试课',
      courseId: '99',
      latitude: 24.4,
      longitude: 118.1,
      placeId: 'place-1',
      obtainedVia: RadarObtainedVia.place.storageKey,
      labelSnapshot: '翔安教学楼',
    );
    final again = CourseRadarPref.fromJson(d.toJson());
    expect(again.courseId, '99');
    expect(again.placeId, 'place-1');
    expect(again.obtainedVia, 'place');
    expect(again.labelSnapshot, '翔安教学楼');
  });

  test('radar card badge is obtainedVia; pref is subtitle', () {
    final copy = radarPlaceCopy(
      const RadarGeoSelection(
        latitude: 24.6,
        longitude: 118.3,
        accuracy: 35,
        obtainedVia: RadarObtainedVia.place,
        placeId: '1',
        label: '翔安教学楼',
        filledFrom: RadarFilledFrom.pref,
      ),
    );
    expect(copy.badge, '预设');
    expect(copy.title, '翔安教学楼');
    expect(copy.subtitle, '本课上次成功用过');
  });

  test('fresh device fix is labeled as current location', () {
    final copy = radarPlaceCopy(
      const RadarGeoSelection(
        latitude: 24.6,
        longitude: 118.3,
        accuracy: 12,
        obtainedVia: RadarObtainedVia.device,
        filledFrom: RadarFilledFrom.user,
      ),
    );
    expect(copy.badge, '系统定位');
    expect(copy.title, '当前位置');
    expect(copy.subtitle, isNull);
  });

  test('pref with placeId resolves saved label without distance guess', () {
    final places = [
      SavedLocation(
        id: 'p1',
        note: '翔安教学楼',
        latitude: 24.60696,
        longitude: 118.30180,
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    final sel = selectionFromCoursePref(
      const CourseRadarPref(
        courseTitle: '工程伦理',
        courseId: '111857',
        latitude: 1,
        longitude: 1,
        placeId: 'p1',
        obtainedVia: 'place',
      ),
      places,
    );
    expect(sel.obtainedVia, RadarObtainedVia.place);
    expect(sel.label, '翔安教学楼');
    expect(sel.latitude, 24.60696);
    expect(radarPlaceCopy(sel).subtitle, '本课上次成功用过');
  });

  test('legacy course memory matches a nearby place when via unknown', () {
    final places = [
      SavedLocation(
        id: '1',
        note: '翔安教学楼',
        latitude: 24.60696,
        longitude: 118.30180,
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    final sel = selectionFromCoursePref(
      const CourseRadarPref(
        courseTitle: '工程伦理',
        latitude: 24.60698,
        longitude: 118.30182,
      ),
      places,
    );
    expect(sel.obtainedVia, RadarObtainedVia.place);
    expect(radarPlaceCopy(sel).title, '翔安教学楼');
    expect(radarPlaceCopy(sel).badge, '预设');
  });

  test('stored device via is not relabeled as a nearby place', () {
    final places = [
      SavedLocation(
        id: '1',
        note: '翔安教学楼',
        latitude: 24.60696,
        longitude: 118.30180,
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    final sel = selectionFromCoursePref(
      const CourseRadarPref(
        courseTitle: '工程伦理',
        latitude: 24.60698,
        longitude: 118.30182,
        obtainedVia: 'device',
      ),
      places,
    );
    expect(sel.obtainedVia, RadarObtainedVia.device);
    expect(radarPlaceCopy(sel).badge, '系统定位');
    expect(radarPlaceCopy(sel).title, '当前位置');
    expect(radarPlaceCopy(sel).subtitle, '本课上次成功用过');
  });

  test('courseRadarStorageKey prefers course id', () {
    expect(
      courseRadarStorageKey(courseId: '111857', courseTitle: '工程伦理'),
      'id:111857',
    );
    expect(courseRadarStorageKey(courseTitle: '工程伦理'), 't:工程伦理');
  });

  test('findNumberCode still works alongside location models', () {
    expect(findNumberCode({'number_code': '0001'}), '0001');
  });
}
