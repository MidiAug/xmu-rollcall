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

  test('CourseRadarDefault round-trip', () {
    final d = CourseRadarDefault(
      courseTitle: '测试课',
      latitude: 24.4,
      longitude: 118.1,
      note: '系统定位',
    );
    final again = CourseRadarDefault.fromJson(d.toJson());
    expect(again.courseTitle, '测试课');
    expect(again.note, '系统定位');
  });

  test('findNumberCode still works alongside location models', () {
    expect(findNumberCode({'number_code': '0001'}), '0001');
  });
}
