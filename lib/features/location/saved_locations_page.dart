import 'location_validation_store.dart';
import 'course_radar_store.dart';
import 'place_buildings.dart';
import 'map_pick_panel.dart' show kMapOverlayInset;
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_map.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'location_providers.dart';
import 'place_matching.dart';
import 'place_providers.dart';

const _locationSplitWidth = 700.0;
const _locationFrameBreakpoint = _locationSplitWidth + 48;

class SavedLocationsPage extends ConsumerStatefulWidget {
  const SavedLocationsPage({super.key});
  @override
  ConsumerState<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends ConsumerState<SavedLocationsPage> {
  var _manager = GlobalKey<_LocationManagerState>();
  (int?, int?)? _identity;
  Campus? _campus;
  bool _mapView = false;
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
      _mapView = false;
    }
    final Campus campus = _campus ?? ref.watch<Campus>(preferredCampusProvider);
    return LayoutBuilder(
      builder: (context, frame) {
        final singlePane = frame.maxWidth < _locationFrameBreakpoint;
        return SubpageScaffold(
          title: singlePane && _mapView ? '地点列表' : '地点管理',
          onBack: singlePane && _mapView
              ? () => _manager.currentState?.showList()
              : null,
          actions: [
            if (!AppMobileUi.useTouchChrome(context) &&
                MediaQuery.sizeOf(context).width >= 720)
              CampusSelector(
                value: campus,
                onChanged: (v) => setState(() => _campus = v),
              )
            else
              AppToolbarChoice<Campus>(
                title: '选择校区',
                value: campus,
                items: Campus.values,
                labelOf: (c) => c.label,
                width: 120,
                onChanged: (v) => setState(() => _campus = v),
              ),
          ],
          body: LocationManagerContent(
            key: _manager,
            campus: campus,
            showMobileListButton: false,
            onMapViewChanged: (value) {
              if (value != _mapView) setState(() => _mapView = value);
            },
          ),
        );
      },
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
    this.showMobileListButton = true,
    this.onMapViewChanged,
  });
  final String? initialRoom;
  final SavedLocation? place;
  final bool readOnly;
  final Campus? campus;
  final bool showMobileListButton;
  final ValueChanged<bool>? onMapViewChanged;
  @override
  ConsumerState<LocationManagerContent> createState() =>
      _LocationManagerState();
}

class _LocationManagerState extends ConsumerState<LocationManagerContent> {
  bool _mobileMap = false, _regionOnly = false;
  String? _focusedRoom;
  String? _focusedBuilding;
  SavedLocation? _selected;
  LatLng? _point;
  LatLng? _viewCenter;
  final _name = TextEditingController();
  bool _creating = false, _busy = false;
  void showList() {
    if (_busy) return;
    setState(() => _mobileMap = false);
    widget.onMapViewChanged?.call(false);
  }

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
    final owner = ref.read(authControllerProvider).profile?.id;
    final scope = ref.read(selectedRollcallAccountProvider);
    final issues =
        ref
            .read(locationIssuesProvider)
            .valueOrNull
            ?.where(
              (e) =>
                  _selected?.id == 'room:issue:${e.point.courseId}' ||
                  e.concerns(
                    _name.text,
                    ref
                        .read(coursePlaceGroupsProvider)
                        .where(
                          (g) =>
                              coursePlaceIdentity(g.name) ==
                              coursePlaceIdentity(_name.text),
                        )
                        .expand((g) => g.courses)
                        .toList(),
                  ),
            )
            .toList() ??
        <LocationValidationIssue>[];
    if (issues.any(
      (e) =>
          e.point.latitude == _point!.latitude &&
          e.point.longitude == _point!.longitude,
    )) {
      setState(() => _error = '请选择与原定位不同的位置后保存');
      return;
    }
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
      if (owner != null) {
        await updateRadarPlaceBindings(owner, scope, issues, place);
        if (!mounted) return;
        ref.invalidate(courseRadarDefaultsForProvider(scope));
      }
      ref.invalidate(locationIssuesProvider);
      setState(() {
        _selected = place;
        _focusedRoom = _name.text;
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

  void _choose(
    String room,
    SavedLocation? place, {
    bool focusMap = true,
    bool correcting = false,
  }) {
    if (_busy) return;
    setState(() {
      _focusedBuilding = null;
      _regionOnly = false;
      _focusedRoom = room;
      _selected = place;
      if (focusMap && place != null) {
        _viewCenter = LatLng(place.latitude, place.longitude);
      }
      _mobileMap = true;
      _point = null;
      _editingId = correcting && place != null && !isReferencePlace(place)
          ? place.id
          : null;
      _creating = place == null || correcting;
      _name.text = room;
      _error = null;
    });
    widget.onMapViewChanged?.call(true);
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
      _focusedBuilding = null;
      _editingId = null;
      _mobileMap = false;
      _name.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onMapViewChanged?.call(_mobileMap);
      });
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
    final issues =
        ref.watch(locationIssuesProvider).valueOrNull ??
        <LocationValidationIssue>[];
    final orphans = issues
        .where((issue) => !groups.any((g) => issue.concerns(g.name, g.courses)))
        .map((issue) {
          final name = issue.point.labelSnapshot.trim().isEmpty
              ? '${issue.point.courseTitle}上课地点'
              : coursePlaceGroup(issue.point.labelSnapshot);
          return ManagedPlaceEntry(
            name,
            SavedLocation(
              id: 'room:issue:${issue.point.courseId}',
              note: name,
              latitude: issue.point.latitude,
              longitude: issue.point.longitude,
              createdAt: issue.at,
            ),
            [issue.point.courseTitle],
          );
        })
        .toList();
    bool inCampus(String name, SavedLocation? place) =>
        (place == null ? campusInName(name) : campusForPoint(place)) ==
            campus ||
        ((place == null ? campusInName(name) : campusForPoint(place)) == null &&
            campus == ref.read(preferredCampusProvider));
    final rawEntries = <ManagedPlaceEntry>[
      ...orphans,
      for (final g in groups)
        ManagedPlaceEntry(g.name, matchCoursePlace(g.name, custom), g.courses),
      for (final preset in teachingPlaces)
        if (!groups.any(
              (g) =>
                  coursePlaceIdentity(g.name) ==
                  coursePlaceIdentity(preset.name),
            ) &&
            !orphans.any(
              (e) =>
                  coursePlaceIdentity(e.name) ==
                  coursePlaceIdentity(preset.name),
            ))
          ManagedPlaceEntry(preset.name, matchCoursePlace(preset.name, custom)),
    ].where((e) => inCampus(e.name, e.place)).toList();
    final allBuildings = groupPlaceEntries(rawEntries);
    final courseIdentities = {
      ...groups.map((g) => coursePlaceIdentity(g.name)),
      ...orphans.map((e) => coursePlaceIdentity(e.name)),
    };
    final entries = groupPlaceEntries(
      rawEntries.where(
        (e) => courseIdentities.contains(coursePlaceIdentity(e.name)),
      ),
    );

    bool needsCorrection(ManagedBuilding b) => b.children.any(
      (e) => issues.any((issue) => issue.concerns(e.name, e.courses)),
    );
    int rank(ManagedBuilding b) => needsCorrection(b)
        ? 0
        : b.pending > 0
        ? 1
        : 2;
    entries.sort((a, b) {
      final status = rank(a).compareTo(rank(b));
      return status != 0 ? status : a.name.compareTo(b.name);
    });
    final activeBuilding = allBuildings
        .where((e) => e.name == _focusedBuilding)
        .firstOrNull;
    void openBuilding(ManagedBuilding building, {bool focusMap = true}) {
      setState(() {
        _focusedBuilding = building.name;
        _regionOnly = false;
        _focusedRoom = null;
        _selected = null;
        _point = null;
        _creating = false;
        _mobileMap = true;
        final fullBuilding =
            allBuildings.where((e) => e.name == building.name).firstOrNull ??
            building;
        if (focusMap && fullBuilding.center != null) {
          _viewCenter = fullBuilding.center;
        }
      });
      widget.onMapViewChanged?.call(true);
    }

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
      child: LayoutBuilder(
        builder: (context, frame) {
          final useSplit = frame.maxWidth >= _locationFrameBreakpoint;
          final fullMap = !useSplit && _mobileMap;
          final inset = useSplit ? kMapOverlayInset : AppMobileUi.inset;
          return Padding(
            padding: fullMap
                ? EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  )
                : EdgeInsets.fromLTRB(
                    useSplit ? 24 : 16,
                    useSplit ? 0 : 12,
                    useSplit ? 24 : 16,
                    (useSplit ? 20 : 16) +
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final wide = useSplit;
                final list = Container(
                  decoration: BoxDecoration(
                    color: wide ? p.surface : Colors.transparent,
                    border: Border.all(
                      color: wide ? p.border : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(wide ? 12 : 0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: entries.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    '本校区暂无课程地点',
                                    style: TextStyle(color: p.muted),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: entries.length,
                                itemBuilder: (context, i) {
                                  final e = entries[i];
                                  final isPending = e.pending > 0;
                                  final invalid = needsCorrection(e);
                                  final status = rank(e);
                                  final rowSelected =
                                      _focusedBuilding == e.name ||
                                      (_focusedRoom != null &&
                                          placeBuildingName(_focusedRoom!) ==
                                              e.name);
                                  final previous = i > 0
                                      ? rank(entries[i - 1])
                                      : null;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (i == 0 || previous != status)
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            wide ? 16 : 0,
                                            10,
                                            wide ? 16 : 0,
                                            8,
                                          ),
                                          child: Text(
                                            invalid
                                                ? '待校正（${entries.where(needsCorrection).length}）'
                                                : isPending
                                                ? '待定位（${entries.where((e) => rank(e) == 1).length}）'
                                                : '已定位（${entries.where((e) => rank(e) == 2).length}）',
                                            style: TextStyle(
                                              color: p.ink,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: wide ? 8 : 0,
                                          vertical: 4,
                                        ),
                                        child: Material(
                                          color: rowSelected
                                              ? Color.alphaBlend(
                                                  p.primary.withValues(
                                                    alpha: .09,
                                                  ),
                                                  p.surface,
                                                )
                                              : p.surface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: rowSelected
                                                  ? p.primary.withValues(
                                                      alpha: .22,
                                                    )
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: ListTile(
                                            key: ValueKey(
                                              'managed-room-${e.name}',
                                            ),
                                            dense: true,
                                            minTileHeight: 56,
                                            minVerticalPadding: 6,
                                            minLeadingWidth: 28,
                                            horizontalTitleGap: 10,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                            leading: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: invalid
                                                    ? p.danger.withValues(
                                                        alpha: .1,
                                                      )
                                                    : isPending
                                                    ? p.surfaceHigh
                                                    : p.primary.withValues(
                                                        alpha: .08,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                e.grouped ||
                                                        e.name.contains('楼')
                                                    ? AppIcons.building
                                                    : AppIcons.location,
                                                size: 17,
                                                color: invalid
                                                    ? p.danger
                                                    : isPending
                                                    ? p.muted
                                                    : p.primary,
                                              ),
                                            ),
                                            title: AppTruncatedText(
                                              e.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontSize: 13,
                                                    color: p.ink,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            subtitle: Tooltip(
                                              message: e.courses.isEmpty
                                                  ? ''
                                                  : e.courses.join('、'),
                                              child: Text(
                                                invalid
                                                    ? '位置校验未通过，点击校正'
                                                    : isPending
                                                    ? (e.courses.isNotEmpty
                                                          ? e.courses.join('、')
                                                          : '${e.pending} 个区域待补全')
                                                    : [
                                                        if (e.grouped)
                                                          '${e.children.length} 个区域',
                                                        if (e
                                                            .courses
                                                            .isNotEmpty)
                                                          '${e.courses.length} 门课程',
                                                        if (!e.grouped &&
                                                            e.courses.isEmpty)
                                                          isTeachingPreset(
                                                                e.place!,
                                                              )
                                                              ? '内置教学地点'
                                                              : isReferencePlace(
                                                                  e.place!,
                                                                )
                                                              ? '楼宇参考'
                                                              : '个人地点',
                                                      ].join('，'),
                                                maxLines: isPending ? 2 : 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontSize: 11,
                                                      color: p.muted,
                                                    ),
                                              ),
                                            ),
                                            trailing: Icon(
                                              AppIcons.right,
                                              size: 15,
                                              color: p.muted,
                                            ),
                                            onTap: _busy
                                                ? null
                                                : () {
                                                    if (!e.grouped &&
                                                        (invalid ||
                                                            e.pending > 0)) {
                                                      _choose(
                                                        e.children.single.name,
                                                        e.place,
                                                        correcting: invalid,
                                                      );
                                                    } else {
                                                      openBuilding(e);
                                                    }
                                                  },
                                          ),
                                        ),
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
                        borderRadius: wide
                            ? const BorderRadius.all(Radius.circular(12))
                            : BorderRadius.zero,
                        overlayInset: inset,
                        center: _viewCenter ?? campus.center,
                        point: point,
                        places: visible,
                        groupBuildings: true,
                        onBuilding: (name) {
                          if (_creating) return;
                          final building = allBuildings
                              .where((e) => e.name == name)
                              .firstOrNull;
                          if (building != null) {
                            openBuilding(building, focusMap: false);
                          }
                        },
                        onPlace: _busy
                            ? null
                            : (place) {
                                if (_creating) {
                                  setState(
                                    () => _point = LatLng(
                                      place.latitude,
                                      place.longitude,
                                    ),
                                  );
                                  return;
                                }
                                final building = allBuildings
                                    .where(
                                      (e) =>
                                          e.name ==
                                          placeBuildingName(place.note),
                                    )
                                    .firstOrNull;
                                if (building != null) {
                                  setState(() {
                                    _focusedBuilding = building.name;
                                    _focusedRoom = place.note;
                                    _selected = place;
                                    _point = null;
                                    _creating = false;
                                    _regionOnly = true;
                                  });
                                } else {
                                  _choose(place.note, place, focusMap: false);
                                }
                              },
                        onTap: widget.readOnly || _busy || !_creating
                            ? null
                            : (value) => setState(() => _point = value),
                      ),
                    ),
                    if (!wide && widget.showMobileListButton)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('map-back-to-list'),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.surface,
                            foregroundColor: p.primary,
                            side: BorderSide(
                              color: p.primary.withValues(alpha: .45),
                            ),
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: .18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: showList,
                          icon: const Icon(AppIcons.back, size: 16),
                          label: const Text('地点列表'),
                        ),
                      ),
                    if (_creating ||
                        _selected != null ||
                        activeBuilding != null)
                      Positioned(
                        right: inset,
                        bottom: inset,
                        left: wide ? null : inset,
                        child: SizedBox(
                          width: wide
                              ? (bounds.maxWidth - 350).clamp(240.0, 340.0)
                              : null,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: (bounds.maxHeight - 2 * inset).clamp(
                                0.0,
                                bounds.maxHeight,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppMobileUi.panelRadius,
                              ),
                              child: SingleChildScrollView(
                                child: activeBuilding != null && !_creating
                                    ? _buildingInspector(
                                        context,
                                        activeBuilding,
                                        regionOnly: _regionOnly
                                            ? _focusedRoom
                                            : null,
                                      )
                                    : _inspector(context),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: inset,
                        bottom: inset,
                        right: inset,
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
                                  '先选择未定位的课表地点，再在地图上选点',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
                if (!wide) {
                  return PopScope(
                    canPop: !_mobileMap,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop && _mobileMap) showList();
                    },
                    child: _mobileMap ? map : list,
                  );
                }
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
          );
        },
      ),
    );
  }

  Widget _buildingInspector(
    BuildContext context,
    ManagedBuilding building, {
    String? regionOnly,
  }) {
    final p = AppPalette.of(context);
    final regions = regionOnly == null
        ? building.children
        : building.children
              .where(
                (e) =>
                    coursePlaceIdentity(e.name) ==
                    coursePlaceIdentity(regionOnly),
              )
              .toList();
    final matched = regions.where((e) => e.courses.isNotEmpty).toList();
    final grouped = regionOnly == null && building.grouped;
    final issues =
        ref.watch(locationIssuesProvider).valueOrNull ??
        <LocationValidationIssue>[];
    final corrections = regions
        .where((e) => issues.any((issue) => issue.concerns(e.name, e.courses)))
        .toList();
    return Material(
      key: const ValueKey('map-building-inspector'),
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMobileUi.panelRadius),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(AppIcons.building, color: p.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    regionOnly ?? building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppSheetCloseButton(
                  tooltip: '关闭地点详情',
                  onPressed: () => setState(() {
                    _focusedBuilding = null;
                    _selected = null;
                    _focusedRoom = null;
                    _regionOnly = false;
                  }),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (matched.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '暂无匹配课程',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: p.muted),
                        ),
                      ),
                    for (final child in regions.where((e) => e.place == null))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _choose(child.name, null),
                          icon: const Icon(AppIcons.location, size: 16),
                          label: Text(
                            '为${placeWing(child.name) == null ? child.name : '${placeWing(child.name)}区'}定位',
                          ),
                        ),
                      ),
                    for (final child in corrections)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _choose(
                                  child.name,
                                  child.place,
                                  correcting: true,
                                ),
                          icon: Icon(
                            AppIcons.location,
                            size: 16,
                            color: p.danger,
                          ),
                          label: Text(
                            '校正${placeWing(child.name) == null ? '位置' : '${placeWing(child.name)}区位置'}',
                          ),
                        ),
                      ),
                    for (final child in matched) ...[
                      if (grouped)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(
                            children: [
                              Text(
                                '${placeWing(child.name) ?? child.name}${placeWing(child.name) == null ? '' : '区'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: p.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      for (final course in child.courses)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            course,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(AppMobileUi.panelRadius),
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
                      _creating
                          ? (selected == null ? '绑定地点' : '校正定位')
                          : _focusedRoom ?? selected?.note ?? '课表地点',
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
              AppSheetCloseButton(
                tooltip: '关闭地点详情',
                enabled: !_busy,
                onPressed: () => setState(() {
                  _creating = false;
                  _selected = null;
                  _point = null;
                  _focusedRoom = null;
                  _focusedBuilding = null;
                }),
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
              readOnly: true,
              decoration: const InputDecoration(
                labelText: '课表地点（名称已锁定）',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              selected?.id.startsWith('room:issue:') == true
                  ? '名称沿用原有课程绑定；请尽量与教务或导入课表的地点名称保持一致。'
                  : '地点名称沿用教务或导入课表，请保持一致以便自动匹配。',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed:
                        _point == null || _name.text.trim().isEmpty || _busy
                        ? null
                        : _save,
                    child: Text(
                      _busy
                          ? '保存中…'
                          : _editingId == null
                          ? '保存坐标'
                          : '保存校正',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
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
            Text('坐标已绑定到课表地点', style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(height: 8),
            if (!widget.readOnly)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _choose(
                        _focusedRoom ?? selected.note,
                        selected,
                        correcting: true,
                      ),
                child: const Text('校正坐标'),
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
