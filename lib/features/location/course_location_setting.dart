import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';

/// Uses the same exact-course preference as radar check-in.
class CourseLocationSetting extends ConsumerStatefulWidget {
  const CourseLocationSetting({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.displayLocation,
  });
  final String courseId;
  final String courseTitle;
  final String? displayLocation;

  @override
  ConsumerState<CourseLocationSetting> createState() =>
      _CourseLocationSettingState();
}

class _CourseLocationSettingState extends ConsumerState<CourseLocationSetting> {
  bool _busy = false;
  bool _saving = false;
  String? _error;

  Future<void> _choose() async {
    final owner = ref.read(authControllerProvider).profile?.id;
    if (owner == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(courseRadarDefaultsProvider.notifier);
      await controller.ready;
      if (!mounted) return;
      final pref = controller.forCourse(courseId: widget.courseId);
      final selected = await showLocationPicker(
        context,
        title: '选择上课地点',
        selectedId: pref?.placeId,
        initial: pref == null ? null : LatLng(pref.latitude, pref.longitude),
      );
      if (!mounted || selected == null) return;
      final auth = ref.read(authControllerProvider);
      if (!auth.isSignedIn || auth.profile?.id != owner) return;
      setState(() => _saving = true);
      await controller.configureForCourse(
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        selection: RadarGeoSelection(
          latitude: selected.latitude,
          longitude: selected.longitude,
          accuracy: selected.accuracy,
          obtainedVia: RadarObtainedVia.place,
          placeId: selected.id,
          label: selected.note,
          filledFrom: RadarFilledFrom.user,
        ),
      );
      if (mounted) AppToast.show(context, '已保存上课地点');
    } catch (_) {
      if (mounted) setState(() => _error = '地点未能保存，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.watch(courseRadarDefaultsProvider);
    final pref = ref
        .read(courseRadarDefaultsProvider.notifier)
        .forCourse(courseId: widget.courseId);
    final p = AppPalette.of(context);
    final location = pref == null
        ? (widget.displayLocation?.trim().isNotEmpty == true
              ? widget.displayLocation!
              : '选择上课地点')
        : pref.labelSnapshot.isEmpty
        ? '已选择地图位置'
        : pref.labelSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppHoverSurface(
            key: const ValueKey('course-location-picker'),
            outlined: false,
            padding: const EdgeInsets.symmetric(vertical: 4),
            onTap:
                auth.isSignedIn && widget.courseId.trim().isNotEmpty && !_busy
                ? _choose
                : null,
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: p.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _saving ? '保存中…' : location,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          pref == null &&
                              widget.displayLocation?.trim().isNotEmpty != true
                          ? p.muted
                          : p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
              ],
            ),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: p.danger),
          ),
      ],
    );
  }
}
