import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';

export 'package:xmu_rollcall/features/location/map_pick_panel.dart';

/// Tap map to choose a point. Uses 高德 raster tiles (OSM often blank in CN).
class MapPickPage extends StatelessWidget {
  const MapPickPage({
    super.key,
    this.initial,
    this.requireNote = false,
    this.title = '选择位置',
    this.confirmLabel,
  });

  final LatLng? initial;
  final bool requireNote;
  final String title;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: title,
      body: MapPickPanel(
        initial: initial,
        requireNote: requireNote,
        confirmLabel: confirmLabel,
        onConfirm: (result) => Navigator.of(context).pop(result),
      ),
    );
  }
}

Future<RadarGeoSelection?> pickSavedLocation(
  BuildContext context,
  List<SavedLocation> locations,
) async {
  final loc = await showLocationPicker(context, locations: locations);
  if (loc == null) return null;
  return RadarGeoSelection(
    latitude: loc.latitude,
    longitude: loc.longitude,
    accuracy: loc.accuracy,
    obtainedVia: RadarObtainedVia.place,
    placeId: loc.id,
    label: loc.note,
    filledFrom: RadarFilledFrom.user,
  );
}
