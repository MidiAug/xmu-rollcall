import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';

enum RadarLocationAction { device, map, preset }

/// Confirmation card: what will be submitted, then one way to change it.
class RadarPlaceCard extends StatelessWidget {
  const RadarPlaceCard({
    super.key,
    required this.selection,
    required this.onChange,
  });

  final RadarGeoSelection? selection;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final current = selection;
    final copy = current == null ? null : radarPlaceCopy(current);

    return Material(
      color: p.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: p.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
          AppSpace.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current == null) ...[
              Text(
                '尚未选择位置',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                '签到前先确认要用的位置',
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ] else ...[
              _SourceBadge(label: copy!.badge),
              const SizedBox(height: AppSpace.xs),
              Text(
                copy.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              if (copy.subtitle != null) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(
                  copy.subtitle!,
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              _PointPreview(
                latitude: current.latitude,
                longitude: current.longitude,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onChange, child: const Text('更换位置')),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: p.selected,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.primary,
        ),
      ),
    );
  }
}

class _PointPreview extends StatelessWidget {
  const _PointPreview({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

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
                        Icons.location_on,
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
                  color: p.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(4),
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
    showDragHandle: true,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      final pageX = AppSpace.pageXOf(ctx);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pageX, 0, pageX, AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '更换位置',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SheetAction(
                icon: Icons.my_location_outlined,
                title: '使用当前定位',
                subtitle: '读取这台设备现在的位置',
                muted: p.muted,
                onTap: () => Navigator.pop(ctx, RadarLocationAction.device),
              ),
              _SheetAction(
                icon: Icons.map_outlined,
                title: '在地图上选择',
                subtitle: '在地图上点一个位置',
                muted: p.muted,
                onTap: () => Navigator.pop(ctx, RadarLocationAction.map),
              ),
              _SheetAction(
                icon: Icons.bookmark_outline,
                title: '已保存的地点',
                subtitle: '使用带备注名的预设位置',
                muted: p.muted,
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
    required this.subtitle,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 28,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
      onTap: onTap,
    );
  }
}
