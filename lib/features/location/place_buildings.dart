import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'place_matching.dart';
import 'teaching_catalog.dart';

String? placeWing(String name) => RegExp(
  r'([ABC])区?$',
  caseSensitive: false,
).firstMatch(coursePlaceGroup(name).trim())?.group(1)?.toUpperCase();

/// Presentation only. Matching and submission keep the original wing identity.
String placeBuildingName(String name) {
  final result = matchTeachingLocation(name);
  if (result != null) {
    final building = teachingBuildings
        .where((b) => b.id == result.buildingId)
        .firstOrNull;
    if (building != null) return building.name.split(RegExp('[（(]')).first;
  }
  var root = coursePlaceGroup(
    name,
  ).replaceFirst(RegExp(r'\s*[A-Za-z]区?$', caseSensitive: false), '').trim();
  for (final c in Campus.values) {
    root = root.replaceAll(c.label, '');
  }
  return root.trim();
}

class ManagedPlaceEntry {
  const ManagedPlaceEntry(this.name, this.place, [this.courses = const []]);
  final String name;
  final SavedLocation? place;
  final List<String> courses;
}

class ManagedBuilding {
  ManagedBuilding(this.name, this.children);
  final String name;
  final List<ManagedPlaceEntry> children;
  bool get grouped =>
      children.length > 1 || children.any((e) => placeWing(e.name) != null);
  int get pending => children.where((e) => e.place == null).length;
  SavedLocation? get place => children.first.place;
  List<String> get courses =>
      children.expand((e) => e.courses).toSet().toList();
  late final LatLng? center = _center();
  LatLng? _center() {
    final actual = children
        .map((e) => e.place)
        .whereType<SavedLocation>()
        .toList();
    if (actual.isEmpty) return null;
    final campus = campusForPoint(actual.first)?.label.replaceFirst('校区', '');
    return _maintainedCenters[(campus, name)] ??
        _boundsCenter(
          actual.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        );
  }
}

LatLng _boundsCenter(List<LatLng> points) => LatLng(
  (points.map((p) => p.latitude).reduce(math.min) +
          points.map((p) => p.latitude).reduce(math.max)) /
      2,
  (points.map((p) => p.longitude).reduce(math.min) +
          points.map((p) => p.longitude).reduce(math.max)) /
      2,
);

final _maintainedCenters = <(String?, String), LatLng>{
  for (final building in teachingBuildings)
    if ([
      building.point,
      ...building.regions.map((r) => r.point),
    ].whereType<TeachingPoint>().any((p) => p.usable))
      (
        building.campus,
        building.name.split(RegExp('[（(]')).first,
      ): _boundsCenter([
        for (final point in [
          building.point,
          ...building.regions.map((r) => r.point),
        ].whereType<TeachingPoint>())
          if (point.usable) LatLng(point.latitude, point.longitude),
      ]),
};

List<ManagedBuilding> groupPlaceEntries(Iterable<ManagedPlaceEntry> entries) {
  final buildings = <String, List<ManagedPlaceEntry>>{};
  for (final entry in entries) {
    final name = placeBuildingName(entry.name);
    (buildings[name] ??= []).add(entry);
  }
  return [for (final e in buildings.entries) ManagedBuilding(e.key, e.value)];
}

List<ManagedBuilding> mapBuildingGroups(List<SavedLocation> places) {
  // Providers put custom coordinates first. Rendering deduplication is not a
  // replacement for ambiguity checks in matching or for explicit submission IDs.
  final unique = <String, SavedLocation>{};
  for (final p in places) {
    unique.putIfAbsent(coursePlaceIdentity(p.note), () => p);
  }
  return groupPlaceEntries(
    unique.values.map((p) => ManagedPlaceEntry(p.note, p)),
  );
}
