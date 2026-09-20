import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/coord_transform.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

void main() {
  test('WGS-84 to GCJ-02 shifts Xiang\'an campus by hundreds of metres', () {
    // Approximate raw GPS near XMU Xiang'an; must not equal GCJ pin on Amap.
    const wgsLat = 24.61269;
    const wgsLon = 118.29925;
    final gcj = wgs84ToGcj02(wgsLat, wgsLon);
    final shiftM = metersBetween(wgsLat, wgsLon, gcj.latitude, gcj.longitude);
    expect(shiftM, greaterThan(200));
    expect(shiftM, lessThan(800));
    expect(gcj.latitude, isNot(wgsLat));
    expect(gcj.longitude, isNot(wgsLon));
  });

  test('outside China leaves coordinates unchanged', () {
    final p = wgs84ToGcj02(37.7749, -122.4194);
    expect(p.latitude, 37.7749);
    expect(p.longitude, -122.4194);
  });
}
