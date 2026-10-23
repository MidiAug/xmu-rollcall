import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';

Future<SavedLocation?> showLocationPicker(
  BuildContext context, {
  String title = '选择地点',
  String? selectedId,
  LatLng? initial,
  List<SavedLocation>? locations,
}) => showDialog<SavedLocation>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .40),
  builder: (_) => _LocationPicker(
    title: title,
    selectedId: selectedId,
    initial: initial,
    locations: locations,
  ),
);

class _LocationPicker extends ConsumerStatefulWidget {
  const _LocationPicker({
    required this.title,
    this.selectedId,
    this.initial,
    this.locations,
  });
  final String title;
  final String? selectedId;
  final LatLng? initial;
  final List<SavedLocation>? locations;
  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  bool _editing = false;
  bool _saving = false;
  MapPickResult? _draft;
  String? _error;

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  Future<void> _save(MapPickResult result) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final place = await ref
          .read(savedLocationsProvider.notifier)
          .add(
            note: result.saveNote!,
            latitude: result.latitude,
            longitude: result.longitude,
          );
      if (mounted) Navigator.pop(context, place);
    } catch (_) {
      if (mounted) setState(() => _error = '地点未能保存，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(savedLocationsProvider);
    final locations = widget.locations ?? saved;
    final initial = _draft == null
        ? widget.initial
        : LatLng(_draft!.latitude, _draft!.longitude);
    return PopScope(
      canPop: !_saving && !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing && !_saving) _back();
      },
      child: Dialog(
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: BorderSide(color: p.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_editing) ...[
                      IconButton(
                        tooltip: '返回地点列表',
                        onPressed: _saving ? null : _back,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        _editing ? '添加地点' : widget.title,
                        style: text.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭地点选择',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_editing)
                  Flexible(
                    child: SizedBox(
                      height: 480,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: MapPickPanel(
                          initial: initial,
                          initialNote: _draft?.saveNote ?? '',
                          requireNote: true,
                          busy: _saving,
                          contentPadding: const EdgeInsets.only(top: 16),
                          confirmLabel: _saving ? '保存中…' : '保存并使用',
                          onDraftChanged: (draft) => _draft = draft,
                          onConfirm: _save,
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (locations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '还没有保存的地点',
                        style: text.bodyMedium?.copyWith(color: p.muted),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: locations.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: p.border),
                        itemBuilder: (_, index) {
                          final place = locations[index];
                          final selected = place.id == widget.selectedId;
                          return AppHoverSurface(
                            outlined: false,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onTap: () => Navigator.pop(context, place),
                            child: Semantics(
                              selected: selected,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      place.note,
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: p.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (locations.isNotEmpty)
                    Divider(height: 16, color: p.border),
                  AppHoverSurface(
                    outlined: false,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: () => setState(() => _editing = true),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: p.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Text('添加地点', style: text.bodyMedium)),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: p.muted,
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: text.bodySmall?.copyWith(color: p.danger),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
