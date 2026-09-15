import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

/// 厦门大学翔安校区（高德 GCJ-02，约 24.6084, 118.3097）。
const LatLng kDefaultMapCenter = LatLng(24.608429, 118.309669);

class MapPickResult {
  const MapPickResult({
    required this.latitude,
    required this.longitude,
    this.saveNote,
  });

  final double latitude;
  final double longitude;
  final String? saveNote;
}

/// Reusable map picker body (embed in pages; no own chrome).
class MapPickPanel extends StatefulWidget {
  const MapPickPanel({
    super.key,
    this.initial,
    this.requireNote = false,
    this.confirmLabel,
    required this.onConfirm,
  });

  final LatLng? initial;
  final bool requireNote;
  final String? confirmLabel;
  final ValueChanged<MapPickResult> onConfirm;

  @override
  State<MapPickPanel> createState() => MapPickPanelState();
}

class MapPickPanelState extends State<MapPickPanel> {
  late LatLng _point;
  final _mapController = MapController();

  LatLng get point => _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? kDefaultMapCenter;
  }

  Future<void> confirm() async {
    String? saveNote;
    if (widget.requireNote) {
      final noteCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('备注名'),
          content: TextField(
            controller: noteCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '如：翔安教学楼',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      final t = noteCtrl.text.trim();
      noteCtrl.dispose();
      if (ok != true || t.isEmpty || !mounted) return;
      saveNote = t;
    }

    if (!mounted) return;
    widget.onConfirm(
      MapPickResult(
        latitude: _point.latitude,
        longitude: _point.longitude,
        saveNote: saveNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final coord =
        '${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}';
    final label = widget.confirmLabel ??
        (widget.requireNote ? '保存' : '完成');

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _point,
            initialZoom: 16,
            onTap: (_, latLng) => setState(() => _point = latLng),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              subdomains: const ['1', '2', '3', '4'],
              userAgentPackageName: 'com.xmu.rollcall',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _point,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.location_on,
                    color: p.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('高德地图'),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpace.pageX,
          right: AppSpace.pageX,
          bottom: AppSpace.md,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                elevation: 2,
                shadowColor: Colors.black26,
                color: p.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          coord,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.ink,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: confirm,
                        child: Text(label),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tap map to choose a point. Uses 高德 raster tiles (OSM often blank in CN).
class MapPickPage extends StatelessWidget {
  const MapPickPage({
    super.key,
    this.initial,
    this.requireNote = false,
    this.title = '选择位置',
  });

  final LatLng? initial;
  final bool requireNote;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: title,
      body: MapPickPanel(
        initial: initial,
        requireNote: requireNote,
        onConfirm: (result) => Navigator.of(context).pop(result),
      ),
    );
  }
}

Future<RadarGeoSelection?> pickSavedLocation(
  BuildContext context,
  List<SavedLocation> locations,
) async {
  if (locations.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('还没有预设点')),
    );
    return null;
  }
  return showModalBottomSheet<RadarGeoSelection>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: locations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final loc = locations[i];
          return ListTile(
            title: Text(loc.note),
            subtitle: Text(
              '${loc.latitude.toStringAsFixed(5)}, '
              '${loc.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: p.muted, fontSize: 12),
            ),
            onTap: () => Navigator.pop(
              ctx,
              RadarGeoSelection(
                latitude: loc.latitude,
                longitude: loc.longitude,
                accuracy: loc.accuracy,
                sourceLabel: loc.note,
              ),
            ),
          );
        },
      );
    },
  );
}
