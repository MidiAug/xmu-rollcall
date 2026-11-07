import 'campus_tile_cache.dart';
import 'place_buildings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'campus_map_config.dart';

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
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.overlayInset = kMapOverlayInset,
    this.controller,
    this.showPlaceLabels = false,
    this.areas = const [],
    this.selectedPlaceId,
    this.onZoomChanged,
    this.onMapReady,
    this.avoidLabelOverlap = false,
  });
  final LatLng center;
  final List<SavedLocation> places;
  final LatLng? point;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<SavedLocation>? onPlace;
  final double zoom;
  final BorderRadius borderRadius;
  final double overlayInset;
  final bool groupBuildings;
  final ValueChanged<String>? onBuilding;
  final MapController? controller;
  final bool showPlaceLabels;
  final List<Polygon> areas;
  final String? selectedPlaceId;
  final ValueChanged<double>? onZoomChanged;
  final VoidCallback? onMapReady;
  final bool avoidLabelOverlap;
  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  late final MapController _controller;
  late List<ManagedBuilding> _groups;
  late int _reportedZoom;
  bool _tileError = false;
  int _tileRevision = 0;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MapController();
    _reportedZoom = widget.zoom.floor();
    _groups = widget.groupBuildings
        ? mapBuildingGroups(widget.places)
        : const [];
  }

  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.places, widget.places) ||
        oldWidget.groupBuildings != widget.groupBuildings) {
      _groups = widget.groupBuildings
          ? mapBuildingGroups(widget.places)
          : const [];
    }
    if (oldWidget.center != widget.center) {
      _controller.move(widget.center, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
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
    bool selected = false,
    String? tooltip,
    required VoidCallback onTap,
  }) {
    final p = AppPalette.of(context);
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : p.primary;
    return Tooltip(
      key: ValueKey(building ? 'map-building-$label' : 'map-place-$tooltip'),
      message: tooltip == label ? '' : tooltip ?? '放大查看$label区域',
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? p.primary : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: p.primary.withValues(alpha: .35)),
          ),
          child: InkWell(
            onTap: onTap,
            // Lift toward theme ink: white over a blue selection would lower
            // white-label contrast, while dark-theme ink lifts the pale accent.
            focusColor: selected ? p.ink.withValues(alpha: .12) : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.location, size: 15, color: foreground),
                  const SizedBox(width: 4),
                  Flexible(
                    child: AppTruncatedText(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildingLayer(BuildContext context, bool expanded) {
    return MarkerLayer(
      markers: [
        for (final entry in _groups.indexed)
          if (!expanded && entry.$2.grouped && entry.$2.center != null)
            Marker(
              point: entry.$2.center!,
              width: _labelWidth(context, entry.$2.name),
              height: 30,
              alignment: Alignment.center,
              child: _mapLabel(
                context,
                entry.$2.name,
                building: true,
                selected: entry.$2.children.any(
                  (item) =>
                      item.place?.id == widget.selectedPlaceId &&
                      widget.selectedPlaceId != null,
                ),
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
                  point: LatLng(place.latitude, place.longitude),
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
                    selected: widget.selectedPlaceId == place.id,
                    onTap: () => widget.onPlace?.call(place),
                  ),
                ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Marker descriptions and label measurements are independent of panning.
    final collapsed = widget.groupBuildings
        ? _buildingLayer(context, false)
        : null;
    final expanded = widget.groupBuildings
        ? _buildingLayer(context, true)
        : null;
    final places = [
      ...widget.places.where((p) => p.id == widget.selectedPlaceId),
      ...widget.places.where((p) => p.id != widget.selectedPlaceId),
    ];
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: widget.zoom.clamp(kXmuMapMinZoom, kAmapMaxZoom),
              minZoom: kXmuMapMinZoom,
              maxZoom: kAmapMaxZoom,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: kXmuMapBounds,
              ),
              onPositionChanged: widget.onZoomChanged == null
                  ? null
                  : (camera, _) {
                      final level = camera.zoom.floor();
                      if (level == _reportedZoom) return;
                      _reportedZoom = level;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          widget.onZoomChanged?.call(_controller.camera.zoom);
                        }
                      });
                    },
              backgroundColor: p.surfaceHigh,
              onMapReady: widget.onMapReady,
              onTap: widget.onTap == null
                  ? null
                  : (_, point) => widget.onTap?.call(point),
            ),
            children: [
              TileLayer(
                tileProvider: CampusTileProvider(),
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
              if (widget.areas.isNotEmpty) PolygonLayer(polygons: widget.areas),
              if (widget.groupBuildings)
                Builder(
                  builder: (context) {
                    return MapCamera.of(context).zoom >= 18
                        ? expanded!
                        : collapsed!;
                  },
                )
              else
                _PlaceMarkerLayer(
                  avoidOverlap: widget.avoidLabelOverlap,
                  markers: [
                    for (final place in places)
                      Marker(
                        key: ValueKey('map-marker-${place.id}'),
                        point: LatLng(place.latitude, place.longitude),
                        width: widget.showPlaceLabels
                            ? _labelWidth(context, place.note)
                            : 36,
                        height: 36,
                        child: widget.showPlaceLabels
                            ? _mapLabel(
                                context,
                                place.note,
                                tooltip: place.note,
                                selected: widget.selectedPlaceId == place.id,
                                onTap: () => widget.onPlace?.call(place),
                              )
                            : Tooltip(
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
          Positioned(
            top: widget.overlayInset,
            right: widget.overlayInset,
            child: MapAttributionControls(),
          ),
        ],
      ),
    );
  }
}

/// Marker descriptions are measured once; only screen-space collision checks
/// depend on the camera. Input order gives the selected label first priority.
class _PlaceMarkerLayer extends StatelessWidget {
  const _PlaceMarkerLayer({required this.markers, required this.avoidOverlap});
  final List<Marker> markers;
  final bool avoidOverlap;

  @override
  Widget build(BuildContext context) {
    if (!avoidOverlap) return MarkerLayer(markers: markers);
    final camera = MapCamera.of(context);
    final viewport = Offset.zero & camera.nonRotatedSize;
    final occupied = <Rect>[];
    final visible = <Marker>[];
    for (final marker in markers) {
      final rect = Rect.fromCenter(
        center: camera.latLngToScreenOffset(marker.point),
        width: marker.width,
        height: marker.height,
      ).inflate(4);
      if (!viewport.overlaps(rect) || occupied.any((r) => r.overlaps(rect))) {
        continue;
      }
      occupied.add(rect);
      visible.add(marker);
    }
    return MarkerLayer(markers: visible);
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
