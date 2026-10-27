import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'map_pick_panel.dart' show kAmapTileUrlTemplate, kAmapTileSubdomains;

/// Map tiles receive viewport coordinates only; no campus account or course data.
class CampusMap extends StatefulWidget {
  const CampusMap({
    super.key,
    required this.center,
    this.places = const [],
    this.point,
    this.onTap,
    this.onPlace,
    this.zoom = 16,
  });
  final LatLng center;
  final List<SavedLocation> places;
  final LatLng? point;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<SavedLocation>? onPlace;
  final double zoom;
  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  final _controller = MapController();
  bool _tileError = false;
  int _tileRevision = 0;
  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _controller.move(widget.center, widget.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: widget.zoom,
          backgroundColor: p.surfaceHigh,
          onTap: (_, point) => widget.onTap?.call(point),
        ),
        children: [
          TileLayer(
            key: ValueKey(_tileRevision),
            errorTileCallback: (_, _, _) {
              if (_tileError) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_tileError) setState(() => _tileError = true);
              });
            },
            urlTemplate: kAmapTileUrlTemplate,
            subdomains: kAmapTileSubdomains,
            userAgentPackageName: 'com.xmu.rollcall',
          ),
          MarkerLayer(
            markers: [
              for (final place in widget.places)
                Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: 36,
                  height: 36,
                  child: Tooltip(
                    message: place.note,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: p.surface,
                        side: BorderSide(
                          color: p.primary.withValues(alpha: .3),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => widget.onPlace?.call(place),
                      icon: Icon(
                        place.id.startsWith('xmu:')
                            ? AppIcons.building
                            : AppIcons.location,
                        size: 18,
                        color: p.primary,
                      ),
                    ),
                  ),
                ),
              if (widget.point != null)
                Marker(
                  point: widget.point!,
                  width: 44,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: Icon(Icons.location_on, color: p.primary, size: 44),
                  ),
                ),
            ],
          ),
          if (_tileError)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '底图暂不可用，请检查网络',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _tileError = false;
                            _tileRevision++;
                          }),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('高德地图 · 楼宇资料：厦门大学校园地图')],
          ),
        ],
      ),
    );
  }
}

class CampusSelector extends StatelessWidget {
  const CampusSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Campus value;
  final ValueChanged<Campus> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: AppSegmentedControl<Campus>(
      value: value,
      onChanged: onChanged,
      segments: [
        for (final c in Campus.values) AppSegment(value: c, label: c.label),
      ],
    ),
  );
}
