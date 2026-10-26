import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';

/// Shares explicit defaults while keeping each meeting's override independent.
class CourseLocationSetting extends ConsumerStatefulWidget {
  const CourseLocationSetting({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.displayLocation,
    this.pickLocation,
    this.assistUserId,
    this.meetingKey,
    this.meetings = const {},
  });
  final String courseId;
  final String courseTitle;
  final int? assistUserId;
  final String? meetingKey;
  final Map<String, String> meetings;
  final String? displayLocation;
  final Future<SavedLocation?> Function(String? selectedId, LatLng? initial)?
  pickLocation;

  @override
  ConsumerState<CourseLocationSetting> createState() =>
      _CourseLocationSettingState();
}

class _CourseLocationSettingState extends ConsumerState<CourseLocationSetting> {
  bool _busy = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
            .reload();
      } catch (_) {
        // Keep the current suggestion if background memory cannot be reloaded.
      }
    });
  }

  Future<void> _choose() async {
    final owner = ref.read(authControllerProvider).profile?.id;
    if (owner == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(
        courseRadarDefaultsForProvider(widget.assistUserId).notifier,
      );
      await controller.reload();
      if (!mounted) return;
      final pref = controller.forCourse(
        courseId: widget.courseId,
        meetingKey: widget.meetingKey,
      );
      final initial = pref == null
          ? null
          : LatLng(pref.latitude, pref.longitude);
      final selected = widget.pickLocation != null
          ? await widget.pickLocation!(pref?.placeId, initial)
          : await showLocationPicker(
              context,
              title: '选择上课地点',
              selectedId: pref?.placeId,
              initial: initial,
            );
      if (!mounted || selected == null) return;
      final targets = widget.meetingKey == null
          ? <String>{}
          : {widget.meetingKey!};
      if (widget.meetings.length > 1) {
        final chosen = await showDialog<Set<String>>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '应用地点：${selected.note}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '首次配置会成为同课默认地点；未单独设置的课次会沿用。勾选其他课次可同时更新，未勾选的独立地点不变。',
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final entry in widget.meetings.entries)
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.value),
                                  value: targets.contains(entry.key),
                                  onChanged: entry.key == widget.meetingKey
                                      ? null
                                      : (v) => update(() {
                                          if (v == true) {
                                            targets.add(entry.key);
                                          } else {
                                            targets.remove(entry.key);
                                          }
                                        }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, targets),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (!mounted || chosen == null) return;
      }
      final auth = ref.read(authControllerProvider);
      if (!auth.isSignedIn || auth.profile?.id != owner) return;
      if (widget.assistUserId != null &&
          !ref
              .read(assistControllerProvider)
              .identities
              .any((identity) => identity.userId == widget.assistUserId)) {
        throw StateError('协助身份已移除');
      }
      setState(() => _saving = true);
      await controller.configureForCourse(
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        meetingKeys: targets,
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
    ref.watch(courseRadarDefaultsForProvider(widget.assistUserId));
    final pref = ref
        .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
        .forCourse(courseId: widget.courseId, meetingKey: widget.meetingKey);
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
        if (pref != null && widget.meetingKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              pref.meetingKey.isEmpty
                  ? '沿用同课默认地点'
                  : pref.userConfigured
                  ? '本次课单独配置的地点'
                  : '本次课上次成功的位置',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
      ],
    );
  }
}
