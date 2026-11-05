import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'academic cache rows reach the actual place provider without losing campus or raw classroom',
    () async {
      SharedPreferences.setMockInitialValues({});
      final source = ['翔安校区主楼群一栋A101', '成智楼（思明）324', '成智楼（翔安）324'];
      final schedule = AcademicSchedule.parse(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        at: DateTime(2026, 11, 3),
        payload: {
          'success': true,
          'ttbList': [],
          'pkjgList': [
            for (var i = 0; i < source.length; i++)
              {
                'KCDM': '$i',
                'BJDM': '$i',
                'KCMC': '测试课程$i',
                'JASMC': source[i],
                'XQ': '1',
                'KSJCDM': '1',
                'JSJCDM': '2',
                'ZCBH': '111111111111111111',
              },
          ],
        },
        clock: {1: (start: 480, end: 525), 2: (start: 535, end: 580)},
      );
      final container = ProviderContainer(
        overrides: [
          campusCachedDataProvider.overrideWith(
            (ref) async => CampusCachedData(schedule: schedule),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(campusCachedDataProvider.future);
      await container.read(savedLocationsProvider.notifier).ready;
      final groups = container.read(coursePlaceGroupsProvider);
      expect(groups, hasLength(3));
      expect(container.read(unmatchedRoomsProvider), isEmpty);
      final locations = container.read(courseRoomLocationsProvider);
      expect(locations, hasLength(3));
      expect(
        locations.singleWhere((p) => p.note.contains('一栋')).latitude,
        24.6050038,
      );
      expect(
        locations
            .where((p) => p.note.contains('成智楼'))
            .map((p) => p.latitude)
            .toSet(),
        hasLength(2),
      );
      expect(schedule.rows.map((r) => r.room), source);
    },
  );
  test('App normalization uses the maintained numeric and campus syntax', () {
    final samples =
        jsonDecode(
              File(
                'test/fixtures/teaching_number_cases.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final n in samples['numbers'] as List) {
      for (final form in n['forms'] as List) {
        for (final suffix in samples['suffixes'] as List) {
          expect(
            normalizePlaceName('$form$suffix'),
            '${n['value']}号楼',
            reason: '$form$suffix',
          );
        }
      }
    }
    for (final name in [
      '主楼群1#A101',
      '主楼群一栋A101',
      '主楼群一号楼A101',
      '翔安校区主楼群Ⅰ号楼A101',
    ]) {
      expect(
        matchCoursePlace(name, [], campus: Campus.xiangan)?.id,
        'xmu:teaching:xuewu-a',
        reason: name,
      );
    }
    expect(matchCoursePlace('1#A101', [], campus: Campus.xiangan), isNull);
    expect(
      matchCoursePlace(
        '1#A101',
        [],
        campus: Campus.xiangan,
        groupId: 'xa-main',
      )?.id,
      'xmu:teaching:xuewu-a',
    );
  });
  test(
    'same-name campus and department rules never borrow missing context',
    () {
      expect(matchCoursePlace('成智楼324', []), isNull);
      final sm = matchCoursePlace('成智楼（思明）324', []);
      final xa = matchCoursePlace('成智楼324', [], campus: Campus.xiangan);
      expect(sm, isNotNull);
      expect(xa, isNotNull);
      expect(sm!.id, isNot(xa!.id));
      expect(matchCoursePlace('A304', [], campus: Campus.siming), isNull);
      expect(matchCoursePlace('A304', [], department: '法学院'), isNull);
      expect(
        matchCoursePlace(
          'A304',
          [],
          campus: Campus.siming,
          department: '法学院',
        )?.note,
        '法学院A楼',
      );
      expect(
        matchCoursePlace('A304', [], campus: Campus.siming, department: '外文学院'),
        isNull,
      );
    },
  );
  test(
    'exact saved region, linked region, building fallback and missing point',
    () {
      expect(matchCoursePlace('学武楼A101', [])?.latitude, 24.6050038);
      expect(
        matchCoursePlace('学武楼G101', [])?.latitude,
        matchCoursePlace('学武楼B101', [])?.latitude,
      );
      final art = matchTeachingLocation('艺术学院G楼雕塑专业教室', campus: '思明');
      expect(art?.point?.source, 'building');
      expect(
        art?.point?.latitude,
        teachingBuildings.singleWhere((b) => b.id == 'sm-art').point?.latitude,
      );
      expect(matchCoursePlace('海韵10共享空间', []), isNull);
      for (final b in teachingBuildings.where(
        (b) => b.point?.source == 'polygon_centroid',
      )) {
        expect(
          matchCoursePlace(
            b.name,
            [],
            campus: Campus.values.firstWhere((c) => c.label == '${b.campus}校区'),
          ),
          isNull,
        );
      }
    },
  );
  test(
    'raw classroom list keeps multiple buildings unresolved and one wing stable',
    () {
      expect(matchCoursePlace('文宣楼B404、C405', []), isNull);
      expect(matchCoursePlace('文宣楼B404、学武楼B405', []), isNull);
      expect(
        matchCoursePlace('文宣楼B404、B405', [])?.id,
        'xmu:teaching:wenxuan-b',
      );
      expect(coursePlaceIdentity('文宣楼B404、405'), 'xmu:teaching:wenxuan-b');
    },
  );
}
