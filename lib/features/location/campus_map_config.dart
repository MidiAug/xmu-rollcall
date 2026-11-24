import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'campus_places.dart';
import 'teaching_catalog.dart';

/// 厦门大学翔安校区（高德 GCJ-02，约 24.6084, 118.3097）。
const LatLng kDefaultMapCenter = LatLng(24.608429, 118.309669);

const String kAmapTileUrlTemplate =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&ltype=11&x={x}&y={y}&z={z}';

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
const double kCampusScopedMinZoom = 13.5;

const InteractionOptions kCampusMapInteractionOptions = InteractionOptions(
  flags: InteractiveFlag.all,
  enableMultiFingerGestureRace: true,
  rotationThreshold: 32.0,
  pinchZoomThreshold: 0.25,
  pinchMoveThreshold: 35.0,
  pinchZoomWinGestures:
      MultiFingerGesture.pinchZoom | MultiFingerGesture.pinchMove,
  pinchMoveWinGestures:
      MultiFingerGesture.pinchZoom | MultiFingerGesture.pinchMove,
  rotationWinGestures: MultiFingerGesture.rotate,
);

const List<String> kAmapTileSubdomains = ['1', '2', '3', '4'];

LatLngBounds _buildCampusBounds(Campus campus) {
  const margin = 0.012;
  final points = <LatLng>[
    campus.center,
    for (final b in teachingBuildings)
      if ('${b.campus}校区' == campus.label) ...[
        if (b.point case final point?) LatLng(point.latitude, point.longitude),
        for (final r in b.regions)
          if (r.point case final point?) LatLng(point.latitude, point.longitude),
      ],
    for (final g in teachingGroups)
      if ('${g.campus}校区' == campus.label) ...[
        if (g.point case final point?) LatLng(point.latitude, point.longitude),
        for (final v in g.vertices) LatLng(v.latitude, v.longitude),
      ],
    for (final p in teachingPlaces)
      if (p.campus == campus) LatLng(p.latitude, p.longitude),
    for (final p in campusPlaces)
      if (p.campus == campus) LatLng(p.latitude, p.longitude),
  ];
  final raw = LatLngBounds.fromPoints(points);
  return LatLngBounds(
    LatLng(
      (raw.south - margin).clamp(kXmuMapBounds.south, kXmuMapBounds.north),
      (raw.west - margin).clamp(kXmuMapBounds.west, kXmuMapBounds.east),
    ),
    LatLng(
      (raw.north + margin).clamp(kXmuMapBounds.south, kXmuMapBounds.north),
      (raw.east + margin).clamp(kXmuMapBounds.west, kXmuMapBounds.east),
    ),
  );
}

final Map<Campus, LatLngBounds> _campusBounds = {
  for (final campus in Campus.values) campus: _buildCampusBounds(campus),
};

LatLngBounds campusBoundsFor(Campus campus) => _campusBounds[campus]!;
