import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// 厦门大学翔安校区（高德 GCJ-02，约 24.6084, 118.3097）。
const LatLng kDefaultMapCenter = LatLng(24.608429, 118.309669);

const String kAmapTileUrlTemplate =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

// This source returns solid-color placeholders beyond z18; overzoom locally.
const int kAmapMaxNativeZoom = 18;
const double kAmapMaxZoom = 21;
const double kMapOverlayInset = 12;

// Covers every maintained point and area in Siming, Xiang'an and Zhangzhou.
final kXmuMapBounds = LatLngBounds(
  const LatLng(24.33, 118.01),
  const LatLng(24.65, 118.35),
);
const double kXmuMapMinZoom = 12;

const List<String> kAmapTileSubdomains = ['1', '2', '3', '4'];
