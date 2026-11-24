import 'package:xmu_rollcall/features/location/campus_tile_cache.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/campus_map_config.dart';

enum RadarLocationAction { device, map, preset }

/// Confirmation card: what will be submitted, then one way to change it.
class RadarPlaceCard extends StatefulWidget {
  const RadarPlaceCard({
    super.key,
    required this.selection,
    required this.onChange,
  });

  final RadarGeoSelection? selection;
  final VoidCallback? onChange;

  @override
  State<RadarPlaceCard> createState() => _RadarPlaceCardState();
}

class _RadarPlaceCardState extends State<RadarPlaceCard> {
  late CampusTileProvider _tileProvider = CampusTileProvider();

  static String? _coordKey(RadarGeoSelection? selection) => selection == null
      ? null
      : '${selection.latitude.toStringAsFixed(5)},${selection.longitude.toStringAsFixed(5)}';

  @override
  void didUpdateWidget(RadarPlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != null &&
        _coordKey(oldWidget.selection) != _coordKey(widget.selection)) {
      // _PointPreview keys FlutterMap by coordinates, so TileLayer disposes the old provider.
      _tileProvider = CampusTileProvider();
    }
  }

  @override
  void dispose() {
    _tileProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final current = widget.selection;
    final copy = current == null ? null : radarPlaceCopy(current);

    return Material(
      color: p.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current == null) ...[
              Text(
                '尚未选择位置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                '签到前先确认要用的位置',
                style: TextStyle(fontSize: 13, height: 1.35, color: p.muted),
              ),
            ] else ...[
              _SourceBadge(label: copy!.badge),
              const SizedBox(height: AppSpace.xs),
              Text(
                copy.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  height: 1.3,
                  color: p.ink,
                ),
              ),
              if (copy.subtitle != null) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(
                  copy.subtitle!,
                  style: TextStyle(fontSize: 12, height: 1.35, color: p.muted),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              _PointPreview(
                latitude: current.latitude,
                longitude: current.longitude,
                tileProvider: _tileProvider,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${current.latitude.toStringAsFixed(5)}, '
                '${current.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  fontSize: 12,
                  color: p.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: widget.onChange,
                child: Text(current == null ? '选择位置' : '更换位置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.2,
          color: p.ink,
        ),
      ),
    );
  }
}

class _PointPreview extends StatelessWidget {
  const _PointPreview({
    required this.latitude,
    required this.longitude,
    required this.tileProvider,
  });

  final double latitude;
  final double longitude;
  final CampusTileProvider tileProvider;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(
                '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}',
              ),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  tileProvider: tileProvider,
                  urlTemplate: kAmapTileUrlTemplate,
                  subdomains: kAmapTileSubdomains,
                  userAgentPackageName: 'com.xmu.rollcall',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        AppIcons.location,
                        color: p.primary,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: p.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '高德地图',
                    style: TextStyle(fontSize: 10, color: p.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<RadarLocationAction?> showRadarLocationSheet(BuildContext context) {
  return showModalBottomSheet<RadarLocationAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: AppPalette.of(context).surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.dialog),
      ),
    ),
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      final pageX = AppSpace.pageXOf(ctx);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pageX, 16, pageX, AppSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text(
                  '更换位置',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: p.ink,
                  ),
                ),
              ),
              _SheetAction(
                icon: AppIcons.locate,
                title: '使用当前定位',
                onTap: () => Navigator.pop(ctx, RadarLocationAction.device),
              ),
              _SheetAction(
                icon: AppIcons.map,
                title: '在地图上选择',
                onTap: () => Navigator.pop(ctx, RadarLocationAction.map),
              ),
              _SheetAction(
                icon: AppIcons.bookmark,
                title: '已保存的地点',
                onTap: () => Navigator.pop(ctx, RadarLocationAction.preset),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: AppHoverSurface(
        onTap: onTap,
        backgroundColor: Colors.transparent,
        hoverColor: p.hover,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.sm,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.muted),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  color: p.ink,
                ),
              ),
            ),
            Icon(AppIcons.right, size: 18, color: p.muted),
          ],
        ),
      ),
    );
  }
}
