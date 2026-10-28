import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'place_matching.dart';

String? placeWing(String name) => RegExp(
  r'([ABC])区?$',
  caseSensitive: false,
).firstMatch(coursePlaceGroup(name).trim())?.group(1)?.toUpperCase();

/// Presentation only. Matching and submission keep the original wing identity.
String placeBuildingName(String name) {
  String parent(String value) {
    var root = coursePlaceGroup(
      value,
    ).replaceFirst(RegExp(r'\s*[ABC]区?$', caseSensitive: false), '').trim();
    for (final c in Campus.values) {
      root = root.replaceAll(c.label, '');
    }
    return root.trim();
  }

  final root = parent(name);
  final normalized = normalizePlaceName(root);
  for (final preset in teachingPlaces) {
    if ([
      preset.name,
      ...preset.aliases,
    ].any((a) => normalizePlaceName(parent(a)) == normalized)) {
      return parent(preset.name);
    }
  }
  return root;
}

class ManagedPlaceEntry {
  const ManagedPlaceEntry(this.name, this.place, [this.courses = const []]);
  final String name;
  final SavedLocation? place;
  final List<String> courses;
}

class ManagedBuilding {
  const ManagedBuilding(this.name, this.children);
  final String name;
  final List<ManagedPlaceEntry> children;
  bool get grouped =>
      children.length > 1 || children.any((e) => placeWing(e.name) != null);
  int get pending => children.where((e) => e.place == null).length;
  SavedLocation? get place => children.first.place;
  List<String> get courses =>
      children.expand((e) => e.courses).toSet().toList();
  LatLng? get center {
    final actual = children
        .map((e) => e.place)
        .whereType<SavedLocation>()
        .toList();
    if (actual.isEmpty) return null;
    // A building's overview center must not move with the user's courses.
    final presetRegions = teachingPlaces
        .where(
          (p) =>
              p.campus == campusForPoint(actual.first) &&
              placeBuildingName(p.name) == name,
        )
        .toList();
    final points = presetRegions.length > 1
        ? presetRegions.map((p) => p.saved).toList()
        : actual;
    // Display-only midpoint of the region bounds, independent of old
    // building reference coordinates or marker label size.
    return LatLng(
      (points.map((p) => p.latitude).reduce(math.min) +
              points.map((p) => p.latitude).reduce(math.max)) /
          2,
      (points.map((p) => p.longitude).reduce(math.min) +
              points.map((p) => p.longitude).reduce(math.max)) /
          2,
    );
  }
}

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
