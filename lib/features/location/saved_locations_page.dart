import 'map_pick_panel.dart' show kMapOverlayInset;
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_map.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'location_providers.dart';
import 'place_matching.dart';
import 'place_providers.dart';

class SavedLocationsPage extends ConsumerStatefulWidget {
  const SavedLocationsPage({super.key});
  @override
  ConsumerState<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends ConsumerState<SavedLocationsPage> {
  var _manager = GlobalKey<_LocationManagerState>();
  (int?, int?)? _identity;
  Campus? _campus;
  @override
  Widget build(BuildContext context) {
    final identity = (
      ref.watch(authControllerProvider).profile?.id,
      ref.watch(selectedRollcallAccountProvider),
    );
    if (identity != _identity) {
      _identity = identity;
      _manager = GlobalKey<_LocationManagerState>();
      _campus = null;
    }
    final Campus campus = _campus ?? ref.watch<Campus>(preferredCampusProvider);
    return SubpageScaffold(
      title: '地点管理',
      actions: [
        if (MediaQuery.sizeOf(context).width >= 720)
          CampusSelector(
            value: campus,
            onChanged: (v) => setState(() => _campus = v),
          )
        else
          DropdownButtonHideUnderline(
            child: DropdownButton<Campus>(
              value: campus,
              items: [
                for (final c in Campus.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c.label, style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _campus = v);
              },
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '添加地点',
          onPressed: () => _manager.currentState?._startNew(),
          icon: const Icon(Icons.add, size: 20),
        ),
      ],
      body: LocationManagerContent(key: _manager, campus: campus),
    );
  }
}

class LocationManagerContent extends ConsumerStatefulWidget {
  const LocationManagerContent({
    super.key,
    this.initialRoom,
    this.place,
    this.readOnly = false,
    this.campus,
  });
  final String? initialRoom;
  final SavedLocation? place;
  final bool readOnly;
  final Campus? campus;
  @override
  ConsumerState<LocationManagerContent> createState() =>
      _LocationManagerState();
}

class _LocationManagerState extends ConsumerState<LocationManagerContent> {
  bool _mine = false, _pendingOnly = false, _mobileMap = false;
  String? _focusedRoom;
  SavedLocation? _selected;
  LatLng? _point;
  LatLng? _viewCenter;
  final _name = TextEditingController();
  String _query = '';
  bool _creating = false, _busy = false;
  String? _error;
  String? _editingId;
  @override
  void initState() {
    super.initState();
    _selected = widget.place;
    if (widget.place != null) {
      _viewCenter = LatLng(widget.place!.latitude, widget.place!.longitude);
    }
    _creating = !widget.readOnly && widget.initialRoom != null;
    _name.text = widget.initialRoom ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_point == null || _name.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(savedLocationsProvider.notifier);
      SavedLocation place;
      if (_editingId != null) {
        await controller.updateCoords(
          _editingId!,
          latitude: _point!.latitude,
          longitude: _point!.longitude,
        );
        await controller.rename(_editingId!, _name.text);
        place = ref
            .read(savedLocationsProvider)
            .firstWhere((p) => p.id == _editingId);
      } else {
        place = await controller.add(
          note: _name.text,
          latitude: _point!.latitude,
          longitude: _point!.longitude,
        );
      }
      if (!mounted) return;
      setState(() {
        _selected = place;
        _focusedRoom = place.note;
        _creating = false;
        _point = null;
        _editingId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '地点未能保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(bool remove) async {
    final place = _selected;
    if (place == null || isReferencePlace(place) || _busy) return;
    final note = remove
        ? null
        : await showAppPromptDialog(
            context,
            title: '重命名',
            initialValue: place.note,
            labelText: '地点名称',
          );
    if (!mounted || (!remove && (note == null || note.trim().isEmpty))) return;
    if (remove &&
        !await showAppConfirmDialog(
          context,
          title: '删除位置',
          message: '删除「${place.note}」？',
          confirmLabel: '删除',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(savedLocationsProvider.notifier);
      if (remove) {
        await ctrl.remove(place.id);
      } else {
        await ctrl.rename(place.id, note!);
      }
      if (mounted) setState(() => _selected = null);
    } catch (_) {
      if (mounted) setState(() => _error = '操作未能保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startNew() {
    if (_busy) return;
    setState(() {
      _mine = true;
      _mobileMap = true;
      _creating = true;
      _selected = null;
      _point = null;
      _editingId = null;
      _focusedRoom = null;
      _name.clear();
      _error = null;
    });
  }

  void _choose(String room, SavedLocation? place, {bool focusMap = true}) {
    if (_busy) return;
    setState(() {
      _focusedRoom = room;
      _selected = place;
      if (focusMap && place != null) {
        _viewCenter = LatLng(place.latitude, place.longitude);
      }
      _mobileMap = true;
      _point = null;
      _editingId = null;
      _creating = place == null;
      _name.text = room;
      _error = null;
    });
  }

  @override
  void didUpdateWidget(covariant LocationManagerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campus != widget.campus && !_busy) {
      _viewCenter = null;
      _selected = null;
      _point = null;
      _creating = false;
      _focusedRoom = null;
      _editingId = null;
      _mobileMap = false;
      _name.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final custom = ref.watch(savedLocationsProvider);
    final places = ref.watch(knownLocationsProvider);
    final Campus campus =
        widget.campus ?? ref.watch<Campus>(preferredCampusProvider);
    final groups = ref.watch(coursePlaceGroupsProvider);
    final rooms = groups.map((g) => g.name);
    final pending = ref.watch(unmatchedRoomsProvider).toSet();
    bool inCampus(String name, SavedLocation? place) =>
        (place == null ? campusInName(name) : campusForPoint(place)) ==
            campus ||
        ((place == null ? campusInName(name) : campusForPoint(place)) == null &&
            campus == ref.read(preferredCampusProvider));
    final entries =
        <({String name, SavedLocation? place})>[
              if (_mine)
                for (final place in custom) (name: place.note, place: place)
              else
                for (final room in rooms)
                  (name: room, place: matchCoursePlace(room, custom)),
            ]
            .where(
              (e) =>
                  inCampus(e.name, e.place) &&
                  (normalizePlaceName(
                        e.name,
                      ).contains(normalizePlaceName(_query)) ||
                      groups
                          .where((g) => g.name == e.name)
                          .any(
                            (g) => normalizePlaceName(
                              g.courses.join(' '),
                            ).contains(normalizePlaceName(_query)),
                          )) &&
                  (!_pendingOnly || _mine || pending.contains(e.name)),
            )
            .toList();
    entries.sort((a, b) {
      final status = (a.place == null ? 0 : 1).compareTo(
        b.place == null ? 0 : 1,
      );
      return status != 0 ? status : a.name.compareTo(b.name);
    });
    final visible = places.where((e) => campusForPoint(e) == campus).toList();
    final point =
        _point ??
        (_selected == null
            ? null
            : LatLng(_selected!.latitude, _selected!.longitude));
    return ShellTabExitGuard(
      hasUnsavedChanges: () =>
          _creating && (_point != null || _name.text.trim().isNotEmpty),
      isBusy: () => _busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
          0,
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 700;
            final list = Container(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppSegmentedControl<bool>(
                            value: _mine,
                            expanded: true,
                            onChanged: (v) => setState(() => _mine = v),
                            segments: const [
                              AppSegment(value: false, label: '课程地点'),
                              AppSegment(value: true, label: '我的地点'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: !_mine
                              ? IconButton(
                                  tooltip: _pendingOnly ? '显示全部地点' : '只看待补全',
                                  isSelected: _pendingOnly,
                                  style: IconButton.styleFrom(
                                    backgroundColor: _pendingOnly
                                        ? p.selected
                                        : Colors.transparent,
                                    foregroundColor: _pendingOnly
                                        ? p.primary
                                        : p.muted,
                                  ),
                                  onPressed: () => setState(
                                    () => _pendingOnly = !_pendingOnly,
                                  ),
                                  icon: const Icon(Icons.filter_list, size: 18),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(AppIcons.search, size: 18),
                        hintText: _mine ? '搜索我的地点' : '搜索课程或地点',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _mine ? '暂无自定义地点，点击右上角添加' : '本校区暂无符合条件的课程地点',
                                style: TextStyle(color: p.muted),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: entries.length,
                            itemBuilder: (context, i) {
                              final e = entries[i];
                              final isPending = e.place == null;
                              final previous = i > 0
                                  ? entries[i - 1].place == null
                                  : null;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (i == 0 || previous != isPending)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        8,
                                      ),
                                      child: Text(
                                        _mine
                                            ? '已保存（${entries.length}）'
                                            : isPending
                                            ? '待补全（${entries.where((e) => e.place == null).length}）'
                                            : '已定位（${entries.where((e) => e.place != null).length}）',
                                        style: TextStyle(
                                          color: p.ink,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  Material(
                                    color: _focusedRoom == e.name
                                        ? p.selected
                                        : Colors.transparent,
                                    child: ListTile(
                                      key: ValueKey('managed-room-${e.name}'),
                                      dense: true,
                                      minTileHeight: 56,
                                      minVerticalPadding: 6,
                                      minLeadingWidth: 20,
                                      horizontalTitleGap: 10,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 0,
                                          ),
                                      leading: Icon(
                                        AppIcons.location,
                                        size: 19,
                                        color: isPending ? p.muted : p.primary,
                                      ),
                                      title: Text(
                                        e.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              color: p.ink,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      subtitle: Text(
                                        isPending
                                            ? (groups
                                                          .where(
                                                            (g) =>
                                                                g.name ==
                                                                e.name,
                                                          )
                                                          .firstOrNull
                                                          ?.courses
                                                          .join('、')
                                                          .isNotEmpty ==
                                                      true
                                                  ? groups
                                                        .firstWhere(
                                                          (g) =>
                                                              g.name == e.name,
                                                        )
                                                        .courses
                                                        .join('、')
                                                  : '课程地点，点击补充位置')
                                            : isReferencePlace(e.place!)
                                            ? '楼宇参考，可补充区域位置'
                                            : '已保存位置',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: p.muted,
                                            ),
                                      ),
                                      trailing: Icon(
                                        AppIcons.right,
                                        size: 16,
                                        color: p.muted,
                                      ),
                                      onTap: _busy
                                          ? null
                                          : () => _choose(e.name, e.place),
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: p.border,
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
            final map = Stack(
              children: [
                Positioned.fill(
                  child: CampusMap(
                    key: ValueKey(campus),
                    center: _viewCenter ?? campus.center,
                    point: point,
                    places: visible,
                    onPlace: _busy
                        ? null
                        : (place) =>
                              _choose(place.note, place, focusMap: false),
                    onTap: widget.readOnly || _busy
                        ? null
                        : (value) => setState(() {
                            if (!_creating) {
                              _editingId = null;
                              _name.text = _focusedRoom ?? '';
                            }
                            _point = value;
                            _creating = true;
                          }),
                  ),
                ),
                if (!wide)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _mobileMap = false),
                      icon: const Icon(AppIcons.back, size: 16),
                      label: const Text('地点列表'),
                    ),
                  ),
                if (_creating || _selected != null)
                  Positioned(
                    right: kMapOverlayInset,
                    bottom: kMapOverlayInset,
                    left: wide ? null : 12,
                    child: SizedBox(
                      width: wide
                          ? (bounds.maxWidth - 350).clamp(240.0, 340.0)
                          : null,
                      child: _inspector(context),
                    ),
                  )
                else
                  Positioned(
                    left: kMapOverlayInset,
                    bottom: kMapOverlayInset,
                    right: kMapOverlayInset,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Material(
                          key: const ValueKey('map-idle-hint'),
                          color: p.surface,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '选择左侧教室，或点击地图添加地点',
                              style: TextStyle(fontSize: 12, color: p.muted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
            if (!wide) return _mobileMap ? map : list;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 300, child: list),
                const SizedBox(width: 16),
                Expanded(child: map),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _inspector(BuildContext context) {
    final p = AppPalette.of(context);
    final selected = _selected;
    final coordinate =
        _point ??
        (selected == null
            ? null
            : LatLng(selected.latitude, selected.longitude));
    return Container(
      key: const ValueKey('map-place-inspector'),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.location, size: 20, color: p.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _focusedRoom ?? selected?.note ?? '添加地点',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (coordinate != null)
                      Tooltip(
                        message: '纬度，经度（GCJ-02）',
                        child: SelectableText(
                          '${coordinate.latitude.toStringAsFixed(6)}, ${coordinate.longitude.toStringAsFixed(6)}',
                          key: const ValueKey('managed-place-coordinates'),
                          style: TextStyle(fontSize: 11, color: p.muted),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭地点详情',
                visualDensity: VisualDensity.compact,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _creating = false;
                        _selected = null;
                        _point = null;
                        _focusedRoom = null;
                      }),
                icon: const Icon(AppIcons.close, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_creating) ...[
            Text(
              _point == null ? '在地图上点选区域位置' : '位置已选择，保存后将重新匹配课程',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('managed-place-name'),
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '地点名称',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _point == null || _name.text.trim().isEmpty || _busy
                        ? null
                        : _save,
                    child: Text(
                      _busy
                          ? '保存中…'
                          : _editingId == null
                          ? '保存地点'
                          : '更新位置',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _creating = false;
                          _point = null;
                        }),
                  child: const Text('取消'),
                ),
              ],
            ),
          ] else if (selected != null) ...[
            Text(
              isReferencePlace(selected) ? '楼宇参考点，可补充区域位置' : '自定义地点',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: 12),
            if (!widget.readOnly)
              Wrap(
                spacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _creating = true;
                            _editingId = isReferencePlace(selected)
                                ? null
                                : selected.id;
                            _name.text = _focusedRoom ?? selected.note;
                            _point = LatLng(
                              selected.latitude,
                              selected.longitude,
                            );
                          }),
                    child: Text(isReferencePlace(selected) ? '补充区域位置' : '调整位置'),
                  ),
                  if (!isReferencePlace(selected)) ...[
                    TextButton(
                      onPressed: _busy ? null : () => _edit(false),
                      child: const Text('重命名'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _edit(true),
                      child: Text('删除', style: TextStyle(color: p.danger)),
                    ),
                  ],
                ],
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: p.danger, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
