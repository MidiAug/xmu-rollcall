import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

SavedLocation custom(
  String id,
  String name, {
  double lat = 24.6045,
  double lon = 118.3114,
}) => SavedLocation(
  id: id,
  note: name,
  latitude: lat,
  longitude: lon,
  createdAt: DateTime(2026),
);
void main() {
  test(
    'only actual timetable classrooms and custom locations are offered on the map',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          courseRoomsProvider.overrideWithValue(['学武楼C201', '西部片区2号楼108']),
        ],
      );
      addTearDown(container.dispose);
      await container.read(savedLocationsProvider.notifier).ready;
      expect(container.read(knownLocationsProvider).map((p) => p.note), [
        '学武楼 C区',
      ]);
      expect(
        container
            .read(knownLocationsProvider)
            .every((p) => p.id.startsWith('room:')),
        isTrue,
      );
      await container
          .read(savedLocationsProvider.notifier)
          .add(note: '西部片区2号楼108', latitude: 24.606, longitude: 118.3);
      expect(
        container.read(knownLocationsProvider).map((p) => p.note).toSet(),
        {'学武楼 C区', '西部片区2号楼108'},
      );
      expect(container.read(unmatchedRoomsProvider), isEmpty);
    },
  );
  test('directory IDs unique and all three campuses represented', () {
    expect(campusPlaces.map((p) => p.id).toSet().length, campusPlaces.length);
    expect(campusPlaces.map((p) => p.campus).toSet(), Campus.values.toSet());
    for (final place in campusPlaces) {
      expect(campusForPoint(place.saved), place.campus);
    }
  });
  test('room aliases, fullwidth, spacing and number normalization', () {
    for (final room in ['学武楼（1号楼） C201', '学武楼(１号楼)Ｃ２０１', '学武楼C201']) {
      expect(matchCoursePlace(room, [])?.note, '学武楼');
    }
    expect(matchCoursePlace('嘉庚三 201', [])?.note, '颂恩楼（嘉庚三）');
  });
  test(
    'exact custom room wins, similar building and multiple rooms do not guess',
    () {
      final point = custom('mine', '西部片区2号楼108');
      expect(matchCoursePlace('西部片区２号楼 108', [point])?.id, 'mine');
      expect(matchCoursePlace('西部片区2号楼109', [point])?.id, 'mine');
      expect(matchCoursePlace('学武楼C201/文宣楼A101', []), isNull);
      expect(
        matchCoursePlace('学武楼C201', [
          custom('a', '学武楼C201'),
          custom('b', '学武楼C201'),
        ]),
        isNull,
      );
    },
  );
  test('cross-campus same names unresolved without explicit campus', () {
    expect(matchCoursePlace('成义楼101', []), isNull);
    expect(
      matchCoursePlace('翔安校区成义楼101', [])?.latitude,
      campusPlaces
          .firstWhere((p) => p.campus == Campus.xiangan && p.name == '成义楼')
          .latitude,
    );
    expect(matchCoursePlace('学武楼C201', [], campus: Campus.zhangzhou), isNull);
  });
  test('default campus derives from majority, fallback deterministic', () {
    expect(
      preferredCampus(['学武楼C201', '文宣楼A101', '海韵教学楼301'], []),
      Campus.xiangan,
    );
    expect(preferredCampus(['未提供地点'], []), Campus.siming);
  });
  test(
    'built-ins cannot be modified through custom storage controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = SavedLocationsController();
      addTearDown(controller.dispose);
      await controller.ready;
      final point = await controller.add(
        note: 'mine',
        latitude: 24.6,
        longitude: 118.3,
      );
      final builtin = campusPlaces.first;
      await controller.remove(builtin.id);
      await controller.rename(builtin.id, 'changed');
      await controller.updateCoords(builtin.id, latitude: 0, longitude: 0);
      expect(controller.state.single.id, point.id);
      expect(campusPlaces.first.name, builtin.name);
    },
  );
  test('known day off differs from absent timetable', () {
    final now = DateTime(2026, 10, 28);
    expect(
      todayDetectionRanges(
        const DetectionWindow(
          enabled: true,
          scheduleBased: true,
          intervals: [],
          hasSchedule: true,
        ),
        now,
      ),
      contains('今日无课'),
    );
    expect(
      todayDetectionRanges(
        const DetectionWindow(
          enabled: true,
          scheduleBased: true,
          intervals: [],
        ),
        now,
      ),
      contains('尚未获取'),
    );
  });
  test('teacher files round-trip without submission files or unsafe links', () {
    final item = HomeworkItem.fromJson({
      'id': 1,
      'attachments': [
        {'name': '材料.pdf', 'url': '/api/file/1', 'size': 2048},
        {'name': 'bad', 'url': 'javascript:alert(1)'},
      ],
      'submissions': [
        {
          'uploads': [
            {'name': 'private'},
          ],
        },
      ],
    });
    expect(item.attachments.length, 2);
    expect(item.attachments.first.url!.host, 'lnt.xmu.edu.cn');
    expect(item.attachments.last.url, isNull);
    expect(HomeworkItem.fromJson(item.toJson()).attachments.first.size, 2048);
    expect(homeworkLink('https://user:secret@example.com'), isNull);
    expect(
      homeworkDescriptionText(
        '<p>说明&nbsp;A</p><script>alert(1)</script><p>&#20013;文</p>',
      ),
      '说明 A\n中文',
    );
  });
}
