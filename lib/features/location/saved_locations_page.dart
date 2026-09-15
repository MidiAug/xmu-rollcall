import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';

class SavedLocationsPage extends ConsumerWidget {
  const SavedLocationsPage({super.key});

  Future<void> _addFromMap(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => const MapPickPage(
          requireNote: true,
          title: '添加位置',
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final note = result.saveNote?.trim() ?? '';
    if (note.isEmpty) return;

    await ref.read(savedLocationsProvider.notifier).add(
          note: note,
          latitude: result.latitude,
          longitude: result.longitude,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存「$note」')),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SavedLocation loc,
  ) async {
    final ctrl = TextEditingController(text: loc.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '备注名'),
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
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || note.isEmpty) return;
    await ref.read(savedLocationsProvider.notifier).rename(loc.id, note);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedLocation loc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('删除「${loc.note}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(savedLocationsProvider.notifier).remove(loc.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(savedLocationsProvider);
    final courseDefaults = ref.watch(courseRadarDefaultsProvider);
    final sortedDefaults = courseDefaults.values.toList()
      ..sort((a, b) => a.courseTitle.compareTo(b.courseTitle));
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '预设位置',
      actions: [
        IconButton(
          tooltip: '添加',
          onPressed: () => _addFromMap(context, ref),
          icon: Icon(Icons.add_location_alt_outlined, color: p.ink),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: list.isEmpty && sortedDefaults.isEmpty
              ? _EmptyState(onAdd: () => _addFromMap(context, ref))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.pageX,
                    AppSpace.md,
                    AppSpace.pageX,
                    AppSpace.xl,
                  ),
                  children: [
                    if (list.isNotEmpty)
                      Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xs,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: p.border),
                              ListTile(
                                title: Text(
                                  list[i].note,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: p.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '${list[i].latitude.toStringAsFixed(5)}, '
                                  '${list[i].longitude.toStringAsFixed(5)}',
                                  style:
                                      TextStyle(fontSize: 12, color: p.muted),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: '重命名',
                                      onPressed: () =>
                                          _rename(context, ref, list[i]),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: p.muted,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除',
                                      onPressed: () =>
                                          _delete(context, ref, list[i]),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: p.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (sortedDefaults.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        '各课默认点',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xs,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < sortedDefaults.length;
                                i++) ...[
                              if (i > 0) Divider(height: 1, color: p.border),
                              ListTile(
                                title: Text(sortedDefaults[i].courseTitle),
                                subtitle: Text(
                                  '${sortedDefaults[i].latitude.toStringAsFixed(5)}, '
                                  '${sortedDefaults[i].longitude.toStringAsFixed(5)}'
                                  '${sortedDefaults[i].note.isEmpty ? "" : " · ${sortedDefaults[i].note}"}',
                                  style:
                                      TextStyle(fontSize: 12, color: p.muted),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 36, color: p.primary),
              const SizedBox(height: AppSpace.sm),
              Text(
                '还没有预设位置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '在地图上点选并命名，雷达签到时可直接选用',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加位置'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
