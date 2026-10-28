import 'place_buildings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'map_pick_panel.dart'
    show
        kAmapTileUrlTemplate,
        kAmapTileSubdomains,
        kAmapMaxNativeZoom,
        kAmapMaxZoom,
        kMapOverlayInset;

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
    this.groupBuildings = false,
    this.onBuilding,
  });
  final LatLng center;
  final List<SavedLocation> places;
  final LatLng? point;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<SavedLocation>? onPlace;
  final double zoom;
  final bool groupBuildings;
  final ValueChanged<String>? onBuilding;
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
      _controller.move(widget.center, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + 37).clamp(58.0, 240.0);
    painter.dispose();
    return width;
  }

  Widget _mapLabel(
    BuildContext context,
    String label, {
    bool building = false,
    String? tooltip,
    required VoidCallback onTap,
  }) {
    final p = AppPalette.of(context);
    return Tooltip(
      key: ValueKey(building ? 'map-building-$label' : 'map-place-$tooltip'),
      message: tooltip ?? '放大查看$label区域',
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.primary.withValues(alpha: .35)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.location, size: 15, color: p.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: widget.zoom.clamp(3, kAmapMaxZoom),
              minZoom: 3,
              maxZoom: kAmapMaxZoom,
              backgroundColor: p.surfaceHigh,
              onTap: (_, point) => widget.onTap?.call(point),
            ),
            children: [
              TileLayer(
                key: ValueKey(_tileRevision),
                maxNativeZoom: kAmapMaxNativeZoom,
                minNativeZoom: 3,
                errorTileCallback: (_, _, _) {
                  if (_tileError) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_tileError) {
                      setState(() => _tileError = true);
                    }
                  });
                },
                urlTemplate: kAmapTileUrlTemplate,
                subdomains: kAmapTileSubdomains,
                userAgentPackageName: 'com.xmu.rollcall',
              ),
              if (widget.groupBuildings)
                Builder(
                  builder: (context) {
                    final expanded = MapCamera.of(context).zoom >= 18;
                    final groups = mapBuildingGroups(widget.places);
                    return MarkerLayer(
                      markers: [
                        for (final entry in groups.indexed)
                          if (!expanded &&
                              entry.$2.grouped &&
                              entry.$2.center != null)
                            Marker(
                              point: entry.$2.center!,
                              width: _labelWidth(context, entry.$2.name),
                              height: 30,
                              alignment: Alignment.center,
                              child: _mapLabel(
                                context,
                                entry.$2.name,
                                building: true,
                                onTap: () {
                                  _controller.move(entry.$2.center!, 18.3);
                                  widget.onBuilding?.call(entry.$2.name);
                                },
                              ),
                            )
                          else
                            for (final item in entry.$2.children)
                              if (item.place case final place?)
                                Marker(
                                  point: LatLng(
                                    place.latitude,
                                    place.longitude,
                                  ),
                                  width: _labelWidth(
                                    context,
                                    placeWing(item.name) == null
                                        ? entry.$2.name
                                        : '${entry.$2.name} ${placeWing(item.name)}区',
                                  ),
                                  height: 36,
                                  child: _mapLabel(
                                    context,
                                    placeWing(item.name) == null
                                        ? entry.$2.name
                                        : '${entry.$2.name} ${placeWing(item.name)}区',
                                    tooltip: item.name,
                                    onTap: () => widget.onPlace?.call(place),
                                  ),
                                ),
                      ],
                    );
                  },
                )
              else
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
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.point != null)
                    Marker(
                      point: widget.point!,
                      width: 44,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.location_on,
                          color: p.primary,
                          size: 44,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_tileError)
            Positioned(
              top: kMapOverlayInset,
              left: kMapOverlayInset,
              right: 100,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Material(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Expanded(
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
          const Positioned(
            top: kMapOverlayInset,
            right: kMapOverlayInset,
            child: MapAttributionControls(),
          ),
        ],
      ),
    );
  }
}

/// Sibling of FlutterMap: controls and their padding never reach map gestures.
class MapAttributionControls extends StatefulWidget {
  const MapAttributionControls({super.key});
  @override
  State<MapAttributionControls> createState() => _MapAttributionControlsState();
}

class _MapAttributionControlsState extends State<MapAttributionControls> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'flutter_map',
                  onPressed: () => setState(() => _open = !_open),
                  icon: Image.asset(
                    'lib/assets/flutter_map_logo.png',
                    package: 'flutter_map',
                    width: 22,
                    height: 22,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  tooltip: _open ? '收起地图来源' : '地图来源',
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(
                    _open ? AppIcons.close : AppIcons.info,
                    size: 19,
                    color: p.muted,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                key: const ValueKey('map-attribution-panel'),
                width: 244,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '© 高德地图\n楼宇资料：厦门大学校园地图\n地图组件：flutter_map',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ),
            ),
          ),
      ],
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
