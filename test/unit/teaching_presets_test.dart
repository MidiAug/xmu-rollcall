import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/place_buildings.dart';

void main() {
  test('curated regions preserve exact user coordinates and room matching', () {
    expect(teachingPlaces.length, 11);
    final a = matchCoursePlace('学武楼（1号楼）A404', [])!;
    final b = matchCoursePlace('学武楼B101', [])!;
    expect(a.latitude, 24.604970);
    expect(a.longitude, 118.313776);
    expect(b.latitude, 24.605494);
    expect(a.id, isNot(b.id));
    expect(matchCoursePlace('坤銮楼（2号楼）C306', [])!.longitude, 118.312816);
    expect(matchCoursePlace('文宣楼（4号楼）B313', [])!.latitude, 24.605236);
    expect(matchCoursePlace('西部片区4号楼106', [])!.longitude, 118.300235);
    expect(matchCoursePlace('西部片区2号楼109', [])!.latitude, 24.604261);
    expect(matchCoursePlace('学信楼108', [])!.latitude, 24.604261);
    expect(coursePlaceIdentity('学信楼108'), coursePlaceIdentity('西部片区2号楼109'));
    expect(coursePlaceIdentity('坤銮楼 A区'), coursePlaceIdentity('坤銮楼（2号楼）A206'));
  });
  test('multiple rooms in the same wing share one location', () {
    for (final name in [
      '文宣楼(4号楼）B404、B405',
      '文宣楼（4号楼）B404、405',
      '文宣楼B404,B405',
      '文宣楼B404/文宣楼B405',
    ]) {
      expect(
        matchCoursePlace(name, [])?.id,
        'xmu:teaching:wenxuan-b',
        reason: name,
      );
      expect(coursePlaceIdentity(name), coursePlaceIdentity('文宣楼B404'));
    }
    expect(matchCoursePlace('文宣楼B404、C405', []), isNull);
    expect(matchCoursePlace('文宣楼B404、学武楼B405', []), isNull);
    expect(matchCoursePlace('文宣楼B404、', []), isNull);
  });
  test('display collapses wings without replacing their submission IDs', () {
    final groups = mapBuildingGroups(
      teachingPlaces.map((p) => p.saved).toList(),
    );
    expect(groups.length, 5);
    final building = groups.singleWhere((g) => g.name == '学武楼');
    expect(building.children.length, 3);
    expect(building.children.map((e) => e.place!.id).toSet().length, 3);
    expect(building.center!.latitude, closeTo(24.6054805, .0000001));
    final kunluan = groups.singleWhere((g) => g.name == '坤銮楼');
    expect(kunluan.center!.latitude, closeTo(24.6055835, .0000001));
    expect(kunluan.center!.longitude, closeTo(118.312744, .0000001));
    final west = groups.singleWhere((g) => g.name == '西部片区2号楼');
    expect(west.center!.latitude, 24.604261);
    expect(west.center!.longitude, 118.299946);
    final onlyA = ManagedBuilding('坤銮楼', [kunluan.children.first]);
    expect(onlyA.center, kunluan.center);
    expect(placeBuildingName('坤銮楼（2号楼） A区'), '坤銮楼');
    expect(placeWing('学武楼（1号楼）A404'), 'A');
    expect(placeBuildingName('翔安校区学武楼（1号楼）A404'), '学武楼');
    expect(coursePlaceIdentity('翔安校区学武楼A404'), coursePlaceIdentity('学武楼A404'));
    expect(placeBuildingName('西部片区4号楼106'), '西部片区4号楼');
  });
}
