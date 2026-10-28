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
    final points = children
        .map((e) => e.place)
        .whereType<SavedLocation>()
        .toList();
    if (points.isEmpty) return null;
    return LatLng(
      points.fold(0.0, (v, p) => v + p.latitude) / points.length,
      points.fold(0.0, (v, p) => v + p.longitude) / points.length,
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
