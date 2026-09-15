import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';

/// Saved GPS presets for radar check-in.
///
/// Interaction model (desktop apps / Maps “Saved places”):
/// - The page **is** the list — not a list/add mode toggle.
/// - “添加” is a chrome action that **pushes** [MapPickPage]; save pops back.
class SavedLocationsPage extends ConsumerStatefulWidget {
  const SavedLocationsPage({super.key});

  @override
  ConsumerState<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends ConsumerState<SavedLocationsPage> {
  Future<void> _openAdd() async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => const MapPickPage(
          requireNote: true,
          title: '添加位置',
        ),
      ),
    );
    if (!mounted || result == null) return;

    final note = result.saveNote?.trim() ?? '';
    if (note.isEmpty) return;

    await ref.read(savedLocationsProvider.notifier).add(
          note: note,
          latitude: result.latitude,
          longitude: result.longitude,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存「$note」')),
    );
  }

  Future<void> _rename(SavedLocation loc) async {
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

  Future<void> _delete(SavedLocation loc) async {
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
  Widget build(BuildContext context) {
    final list = ref.watch(savedLocationsProvider);
    final courseDefaults = ref.watch(courseRadarDefaultsProvider);
    final sortedDefaults = courseDefaults.values.toList()
      ..sort((a, b) => a.courseTitle.compareTo(b.courseTitle));
    final p = AppPalette.of(context);
    final empty = list.isEmpty && sortedDefaults.isEmpty;

    return SubpageScaffold(
      title: '预设位置',
      actions: [
        TextButton.icon(
          onPressed: _openAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('添加'),
          style: TextButton.styleFrom(
            foregroundColor: p.primary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: empty
              ? _EmptyState(onAdd: _openAdd)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.pageX,
                    AppSpace.md,
                    AppSpace.pageX,
                    AppSpace.xl,
                  ),
                  children: [
                    if (list.isNotEmpty) ...[
                      _SectionLabel(
                        label: '我的位置',
                        count: list.length,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xs,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: p.border),
                              _LocationTile(
                                title: list[i].note,
                                subtitle:
                                    '${list[i].latitude.toStringAsFixed(5)}, '
                                    '${list[i].longitude.toStringAsFixed(5)}',
                                onRename: () => _rename(list[i]),
                                onDelete: () => _delete(list[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (sortedDefaults.isNotEmpty) ...[
                      if (list.isNotEmpty)
                        const SizedBox(height: AppSpace.lg),
                      const _SectionLabel(label: '各课默认点'),
                      const SizedBox(height: AppSpace.xs),
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
                              if (i > 0)
                                Divider(height: 1, color: p.border),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.xs,
                                ),
                                leading: Icon(
                                  Icons.school_outlined,
                                  size: 20,
                                  color: p.muted,
                                ),
                                title: Text(sortedDefaults[i].courseTitle),
                                subtitle: Text(
                                  '${sortedDefaults[i].latitude.toStringAsFixed(5)}, '
                                  '${sortedDefaults[i].longitude.toStringAsFixed(5)}'
                                  '${sortedDefaults[i].note.isEmpty ? "" : " · ${sortedDefaults[i].note}"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.muted,
                                  ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: p.muted,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpace.xs),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.subtitle,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Icon(Icons.place_outlined, size: 18, color: p.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: p.ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: p.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '重命名',
            onPressed: onRename,
            icon: Icon(Icons.edit_outlined, color: p.muted, size: 18),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: p.danger, size: 18),
          ),
        ],
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppRadii.dialog),
                  border: Border.all(color: p.borderStrong),
                ),
                child: Icon(Icons.place_outlined, size: 28, color: p.primary),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                '还没有预设位置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '在地图上点选并命名，雷达签到时可直接选用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加位置'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
