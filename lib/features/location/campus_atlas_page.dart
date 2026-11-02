import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_map.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'teaching_catalog.dart';

String _regionLabel(TeachingRegion r) =>
    RegExp(r'[区楼栋座]$').hasMatch(r.code) ? r.code : '${r.code}区';

/// Public maintained directory. No account providers, edits or location binding.
class CampusAtlasPage extends StatefulWidget {
  const CampusAtlasPage({super.key});
  @override
  State<CampusAtlasPage> createState() => _CampusAtlasPageState();
}

class _CampusAtlasPageState extends State<CampusAtlasPage> {
  final _map = MapController();
  Campus _campus = Campus.xiangan;
  String? _groupId, _buildingId, _regionId;
  int _level = 0;

  List<TeachingBuilding> get _buildings =>
      teachingBuildings.where((b) => '${b.campus}校区' == _campus.label).toList();
  List<TeachingGroup> get _groups =>
      teachingGroups.where((g) => '${g.campus}校区' == _campus.label).toList();
  TeachingPoint? _position(TeachingBuilding b) => b.point?.usable == true
      ? b.point
      : b.regions
            .map((r) => r.point)
            .whereType<TeachingPoint>()
            .where((p) => p.usable)
            .firstOrNull;
  TeachingPoint? _groupPosition(TeachingGroup g) =>
      g.point ??
      _buildings
          .where((b) => b.groupId == g.id)
          .map(_position)
          .whereType<TeachingPoint>()
          .firstOrNull;
  SavedLocation _location(TeachingPoint p, {String? id, String? name}) =>
      SavedLocation(
        id: id ?? p.id,
        note: name ?? p.name,
        latitude: p.latitude,
        longitude: p.longitude,
        createdAt: DateTime(2026, 11, 3),
      );

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fitCampus() {
    final points = <LatLng>[
      for (final b in _buildings)
        for (final point in [
          b.point,
          ...b.regions.map((r) => r.point),
        ].whereType<TeachingPoint>())
          if (point.usable) LatLng(point.latitude, point.longitude),
      for (final g in _groups)
        for (final v in g.vertices) LatLng(v.latitude, v.longitude),
    ];
    if (points.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 180),
        maxZoom: 16,
      ),
    );
  }

  void _overview() {
    setState(() {
      _groupId = null;
      _buildingId = null;
      _regionId = null;
      _level = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitCampus();
    });
  }

  void _selectGroup(String? id) {
    if (id == null) {
      _overview();
      return;
    }
    final group = _groups.where((g) => g.id == id).firstOrNull;
    final point = group == null ? null : _groupPosition(group);
    setState(() {
      _groupId = id;
      _buildingId = null;
      _regionId = null;
      _level = 1;
    });
    _map.move(
      point == null ? _campus.center : LatLng(point.latitude, point.longitude),
      17.3,
    );
  }

  void _selectBuilding(TeachingBuilding b, [TeachingRegion? region]) {
    final point = region?.point ?? _position(b);
    setState(() {
      _groupId = b.groupId.isEmpty ? '_independent' : b.groupId;
      _buildingId = b.id;
      _regionId = region?.id;
      _level = b.regions.isEmpty ? 1 : 2;
    });
    if (point?.usable == true) {
      _map.move(
        LatLng(point!.latitude, point.longitude),
        b.regions.isEmpty ? 18.3 : 19.2,
      );
    }
  }

  Widget _directory({bool mobile = false}) => _AtlasDirectory(
    key: ValueKey('atlas-directory-${_campus.name}'),
    campus: _campus,
    groupId: _groupId,
    buildingId: _buildingId,
    regionId: _regionId,
    mobile: mobile,
    onGroup: _selectGroup,
    onBuilding: (b) {
      _selectBuilding(b);
      if (mobile) Navigator.of(context).pop();
    },
    onRegion: (b, r) => _selectBuilding(b, r),
  );

  void _openDirectory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .76,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_campus.label}目录',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭目录',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(AppIcons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _directory(mobile: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final buildings = _buildings, groups = _groups;
    final building = buildings.where((b) => b.id == _buildingId).firstOrNull;
    final region = building?.regions
        .where((r) => r.id == _regionId)
        .firstOrNull;
    final group = groups.where((g) => g.id == _groupId).firstOrNull;
    final groupIds = groups.map((g) => g.id).toSet();
    final filtered = buildings
        .where(
          (b) =>
              _groupId == null ||
              (_groupId == '_independent'
                  ? !groupIds.contains(b.groupId)
                  : b.groupId == _groupId),
        )
        .toList();
    final points = <SavedLocation>[
      if (_level == 0 && _groupId == null && building == null) ...[
        for (final g in groups)
          if (_groupPosition(g) case final point?)
            _location(point, id: 'atlas-group:${g.id}', name: g.name),
        for (final b in buildings.where((b) => !groupIds.contains(b.groupId)))
          if (_position(b) case final point?) _location(point, name: b.name),
      ] else
        for (final b in filtered)
          if (_level >= 2 &&
              b.regions.any((r) => r.point?.source == 'region')) ...[
            for (final r in b.regions)
              if (r.point case final point? when point.source == 'region')
                _location(point),
          ] else if (_position(b) case final point?)
            _location(point, name: b.name),
    ];
    final selected = region?.point ?? building?.point;
    final polygons = <Polygon>[
      for (final g in groups)
        if (g.vertices.length >= 3)
          Polygon(
            points: [
              for (final v in g.vertices) LatLng(v.latitude, v.longitude),
            ],
            color: p.primary.withValues(alpha: g.id == _groupId ? .13 : .025),
            borderColor: p.primary.withValues(
              alpha: g.id == _groupId ? .75 : .2,
            ),
            borderStrokeWidth: g.id == _groupId ? 2 : 1,
          ),
    ];
    return LayoutBuilder(
      builder: (context, frame) {
        final mobile = frame.maxWidth < 800;
        return SubpageScaffold(
          title: '校园地图',
          actions: [
            if (mobile)
              AppToolbarChoice<Campus>(
                title: '选择校区',
                value: _campus,
                items: Campus.values,
                labelOf: (c) => c.label,
                width: 120,
                onChanged: (c) {
                  setState(() => _campus = c);
                  _overview();
                },
              )
            else
              CampusSelector(
                value: _campus,
                onChanged: (c) {
                  setState(() => _campus = c);
                  _overview();
                },
              ),
          ],
          body: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 0 : 24,
              mobile ? 0 : 4,
              mobile ? 0 : 24,
              mobile ? 0 : 20,
            ),
            child: Row(
              children: [
                if (!mobile) ...[
                  SizedBox(
                    width: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border.all(color: p.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _directory(),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CampusMap(
                          key: const ValueKey('campus-atlas-map'),
                          controller: _map,
                          center: _campus.center,
                          zoom: 16,
                          places: points,
                          showPlaceLabels: !mobile || _level > 0,
                          onMapReady: _fitCampus,
                          areas: polygons,
                          selectedPlaceId: selected?.id,
                          borderRadius: mobile
                              ? BorderRadius.zero
                              : BorderRadius.circular(14),
                          onZoomChanged: (zoom) {
                            final next = zoom >= 19
                                ? 2
                                : zoom >= 17
                                ? 1
                                : 0;
                            if (_level != next) setState(() => _level = next);
                          },
                          onPlace: (place) {
                            if (place.id.startsWith('atlas-group:')) {
                              _selectGroup(
                                place.id.substring('atlas-group:'.length),
                              );
                              return;
                            }
                            for (final b in buildings) {
                              final r = b.regions
                                  .where((r) => r.point?.id == place.id)
                                  .firstOrNull;
                              if (r != null || b.point?.id == place.id) {
                                _selectBuilding(b, r);
                                return;
                              }
                            }
                          },
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            '${buildings.length} 栋楼宇',
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom:
                            14 +
                            (mobile ? MediaQuery.paddingOf(context).bottom : 0),
                        right: 14,
                        left: mobile ? 14 : null,
                        child: SizedBox(
                          width: mobile ? null : 320,
                          child: Container(
                            key: const ValueKey('atlas-selection'),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: p.surface,
                              border: Border.all(color: p.border),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: p.ink.withValues(alpha: .04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      AppIcons.building,
                                      color: p.primary,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppTruncatedText(
                                        region?.aliases.firstOrNull ??
                                            building?.name ??
                                            group?.name ??
                                            '浏览${_campus.label}',
                                        style: TextStyle(
                                          color: p.ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (mobile)
                                      TextButton.icon(
                                        key: const ValueKey(
                                          'atlas-open-directory',
                                        ),
                                        onPressed: _openDirectory,
                                        icon: const Icon(
                                          AppIcons.tools,
                                          size: 17,
                                        ),
                                        label: const Text('目录'),
                                      ),
                                    IconButton(
                                      tooltip: '校区全览',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _overview,
                                      icon: const Icon(
                                        AppIcons.refresh,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  building == null
                                      ? group == null
                                            ? '选择楼群或搜索楼宇，查看校园位置'
                                            : '${group.kind}，${filtered.length} 栋楼宇'
                                      : selected?.usable != true
                                      ? '尚未维护定位'
                                      : selected!.source == 'building' &&
                                            region != null
                                      ? '沿用楼宇位置'
                                      : selected.source == 'linked_region'
                                      ? '沿用关联分区位置'
                                      : selected.source == 'group'
                                      ? '沿用楼群位置'
                                      : region == null
                                      ? '楼宇位置'
                                      : '分区独立位置',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (building != null &&
                                    region == null &&
                                    building.aliases.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: AppTruncatedText(
                                      '别名：${building.aliases.join('、')}',
                                      style: TextStyle(
                                        color: p.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (mobile &&
                                    building != null &&
                                    building.regions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (final r in building.regions)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: ChoiceChip(
                                                labelStyle: TextStyle(
                                                  fontFamily:
                                                      AppTypography.family,
                                                  fontFamilyFallback:
                                                      AppTypography.fallback,
                                                ),
                                                label: Text(_regionLabel(r)),
                                                selected: _regionId == r.id,
                                                onSelected: (_) =>
                                                    _selectBuilding(
                                                      building,
                                                      r,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AtlasDirectory extends StatefulWidget {
  const _AtlasDirectory({
    super.key,
    required this.campus,
    required this.mobile,
    this.groupId,
    this.buildingId,
    this.regionId,
    required this.onGroup,
    required this.onBuilding,
    required this.onRegion,
  });
  final Campus campus;
  final bool mobile;
  final String? groupId, buildingId, regionId;
  final ValueChanged<String?> onGroup;
  final ValueChanged<TeachingBuilding> onBuilding;
  final void Function(TeachingBuilding, TeachingRegion) onRegion;
  @override
  State<_AtlasDirectory> createState() => _AtlasDirectoryState();
}

class _AtlasDirectoryState extends State<_AtlasDirectory> {
  final _search = TextEditingController();
  String? _groupId;
  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  void didUpdateWidget(_AtlasDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _groupId = widget.groupId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final groups = teachingGroups
        .where((g) => '${g.campus}校区' == widget.campus.label)
        .toList();
    final buildings = teachingBuildings
        .where((b) => '${b.campus}校区' == widget.campus.label)
        .toList();
    final groupIds = groups.map((g) => g.id).toSet();
    final query = normalizeTeachingName(_search.text);
    final visible = buildings
        .where(
          (b) =>
              (query.isNotEmpty ||
                  _groupId == null ||
                  (_groupId == '_independent'
                      ? !groupIds.contains(b.groupId)
                      : b.groupId == _groupId)) &&
              (query.isEmpty ||
                  [
                    b.name,
                    ...b.aliases,
                    ...b.regions.expand((r) => r.aliases),
                  ].any((n) => normalizeTeachingName(n).contains(query))),
        )
        .toList();
    final sections = <({String? id, String name, int count})>[
      (id: null, name: '全部楼宇', count: buildings.length),
      for (final g in groups)
        (
          id: g.id,
          name: g.name,
          count: buildings.where((b) => b.groupId == g.id).length,
        ),
      (
        id: '_independent',
        name: '独立楼宇',
        count: buildings.where((b) => !groupIds.contains(b.groupId)).length,
      ),
    ];
    void selectGroup(String? id) {
      setState(() => _groupId = id);
      widget.onGroup(id);
    }

    final list = visible.isEmpty
        ? Center(
            child: Text('没有找到对应楼宇', style: TextStyle(color: p.muted)),
          )
        : ListView.builder(
            key: const ValueKey('atlas-building-list'),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final b = visible[i], active = widget.buildingId == visible[i].id;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: active ? p.accentSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        key: ValueKey('atlas-building-${b.id}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.onBuilding(b),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppTruncatedText(
                                      b.name,
                                      style: TextStyle(
                                        color: active ? p.primary : p.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      b.point?.usable == true
                                          ? b.regions.isEmpty
                                                ? '楼宇定位'
                                                : '${b.regions.length} 个分区'
                                          : '定位待补充',
                                      style: TextStyle(
                                        color: p.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(AppIcons.right, color: p.muted, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.mobile && active)
                    for (final r in b.regions)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 2),
                        child: Material(
                          color: widget.regionId == r.id
                              ? p.accentSurface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            key: ValueKey('atlas-region-${r.id}'),
                            onTap: () => widget.onRegion(b, r),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 18,
                                    color: p.primary.withValues(alpha: .2),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppTruncatedText(
                                      _regionLabel(r),
                                      style: TextStyle(
                                        color: p.ink,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    r.point?.source == 'region'
                                        ? '独立定位'
                                        : r.point?.usable == true
                                        ? '沿用定位'
                                        : '未定位',
                                    style: TextStyle(
                                      color: p.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const ValueKey('atlas-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索楼名、别名或分区',
              prefixIcon: const Icon(AppIcons.search),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      icon: const Icon(AppIcons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            '${visible.length} 栋楼宇',
            style: TextStyle(fontSize: 11, color: p.muted),
          ),
        ),
        if (widget.mobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final s in sections)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        labelStyle: TextStyle(
                          fontFamily: AppTypography.family,
                          fontFamilyFallback: AppTypography.fallback,
                        ),
                        label: Text(s.name),
                        selected: _groupId == s.id,
                        onSelected: (_) => selectGroup(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: widget.mobile
              ? list
              : Row(
                  children: [
                    SizedBox(
                      width: 108,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 12),
                        children: [
                          for (final s in sections)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Material(
                                color: _groupId == s.id
                                    ? p.accentSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  key: ValueKey('atlas-group-${s.id ?? 'all'}'),
                                  onTap: () => selectGroup(s.id),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _groupId == s.id
                                                ? p.primary
                                                : p.muted,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${s.count}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: p.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    VerticalDivider(width: 1, color: p.border),
                    Expanded(child: list),
                  ],
                ),
        ),
      ],
    );
  }
}
