import 'dart:math' as math;

/// China map offset: device GPS is usually WGS-84; 高德 tiles / campus pickers use GCJ-02.
///
/// Mixing them on the preview map shifts the pin by a few hundred metres.
class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Convert a WGS-84 fix to GCJ-02 for display and radar submit (China mainland).
LatLngPoint wgs84ToGcj02(double latitude, double longitude) {
  if (!_inChina(latitude, longitude)) {
    return LatLngPoint(latitude, longitude);
  }
  final d = _delta(latitude, longitude);
  return LatLngPoint(latitude + d.latitude, longitude + d.longitude);
}

bool _inChina(double lat, double lon) {
  return lon > 73.66 && lon < 135.05 && lat > 3.86 && lat < 53.55;
}

LatLngPoint _delta(double lat, double lon) {
  const a = 6378245.0;
  const ee = 0.00669342162296594323;
  var dLat = _transformLat(lon - 105.0, lat - 35.0);
  var dLon = _transformLon(lon - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
  dLon = (dLon * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
  return LatLngPoint(dLat, dLon);
}

double _transformLat(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (160.0 * math.sin(y / 12.0 * math.pi) +
          320.0 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLon(double x, double y) {
  var ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}
