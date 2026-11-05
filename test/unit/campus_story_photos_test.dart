import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/campus_story_photos.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';

void main() {
  test(
    'official photos refer to actual stable building and collection identities',
    () {
      final identities = {
        ...teachingBuildings.map((b) => 'building:${b.id}'),
        ...teachingGroups.map((g) => 'group:${g.id}'),
      };
      for (final entry in campusStoryPhotos.entries) {
        expect(identities, contains(entry.key));
        for (final value in [entry.value.url, entry.value.sourceUrl]) {
          final uri = Uri.parse(value);
          expect(uri.scheme, 'https');
          expect(uri.host.endsWith('.xmu.edu.cn'), isTrue);
          expect(uri.userInfo, isEmpty);
        }
        expect(entry.value.caption, isNotEmpty);
        expect(entry.value.credit, isNotEmpty);
      }
    },
  );
  test('individual buildings never inherit an unrelated collection photo', () {
    final group = teachingGroups.singleWhere((g) => g.id == 'sm-jiageng');
    final member = teachingBuildings.singleWhere((b) => b.id == 'sm-jiageng1');
    expect(campusStoryPhotoFor(group: group), isNotNull);
    expect(campusStoryPhotoFor(building: member, group: group), isNull);
    final pool = teachingBuildings.singleWhere((b) => b.id == 'xa-pool');
    expect(campusStoryPhotoFor(building: pool)!.caption, '佘明培游泳馆');
  });
}
