import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_map.dart';
import 'campus_map_config.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'teaching_catalog.dart';
import 'campus_stories.dart';
import 'campus_story_dialog.dart';

String _regionLabel(TeachingRegion r) =>
    RegExp(r'[区楼栋座]$').hasMatch(r.code) ? r.code : '${r.code}区';

// Maintenance buckets are not geographic groups and must not aggregate pins.
bool _mapGroup(TeachingGroup group) => !group.id.startsWith('independent-');

/// Public maintained directory. No account providers, edits or location binding.
class CampusAtlasPage extends StatefulWidget {
  const CampusAtlasPage({super.key, this.initialCampus = Campus.xiangan});
  final Campus initialCampus;
  @override
  State<CampusAtlasPage> createState() => _CampusAtlasPageState();
}

class _CampusAtlasPageState extends State<CampusAtlasPage> {
  MapController _map = MapController();
  late Campus _campus;
  bool _manualCampus = false;
  String? _groupId, _buildingId, _regionId;
  int _level = 0;
  int _mapSelectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _campus = widget.initialCampus;
  }

  @override
  void didUpdateWidget(covariant CampusAtlasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_manualCampus && oldWidget.initialCampus != widget.initialCampus) {
      _switchCampus(widget.initialCampus);
    }
  }

  void _switchCampus(Campus campus) {
    if (_campus == campus) return;
    final previous = _map;
    setState(() {
      _campus = campus;
      _map = MapController();
      _groupId = null;
      _buildingId = null;
      _regionId = null;
      _level = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  List<TeachingBuilding> get _buildings =>
      teachingBuildings.where((b) => '${b.campus}校区' == _campus.label).toList();
  List<TeachingGroup> get _groups => teachingGroups
      .where((g) => '${g.campus}校区' == _campus.label && _mapGroup(g))
      .toList();
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

  CameraFit? _campusCameraFit() {
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
    if (points.isEmpty) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 180),
      maxZoom: 16,
    );
  }

  void _fitCampus() {
    final fit = _campusCameraFit();
    if (fit != null) _map.fitCamera(fit);
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

  void _selectGroup(String? id, {bool moveCamera = true}) {
    if (id == null) {
      _overview();
      return;
    }
    if (id == '_all' || id == '_other') {
      setState(() {
        _groupId = id;
        _buildingId = null;
        _regionId = null;
      });
      return;
    }
    final group = _groups.where((g) => g.id == id).firstOrNull;
    final point = group == null ? null : _groupPosition(group);
    setState(() {
      _groupId = id;
      _buildingId = null;
      _regionId = null;
      if (!moveCamera) _mapSelectionRevision++;
    });
    if (moveCamera) {
      _map.move(
        point == null
            ? _campus.center
            : LatLng(point.latitude, point.longitude),
        17.3,
      );
    }
  }

  void _selectBuilding(
    TeachingBuilding b, {
    TeachingRegion? region,
    bool moveCamera = true,
  }) {
    final point = region?.point ?? _position(b);
    setState(() {
      _groupId = _groups.any((g) => g.id == b.groupId) ? b.groupId : '_other';
      _buildingId = b.id;
      _regionId = region?.id;
      if (!moveCamera) _mapSelectionRevision++;
    });
    if (moveCamera && point?.usable == true) {
      _map.move(
        LatLng(point!.latitude, point.longitude),
        b.regions.isEmpty ? 17.3 : 18.2,
      );
    }
  }

  Widget _directory({bool mobile = false}) => _AtlasDirectory(
    key: ValueKey('atlas-directory-${_campus.name}'),
    campus: _campus,
    groupId: _groupId,
    buildingId: _buildingId,
    regionId: _regionId,
    mapSelectionRevision: _mapSelectionRevision,
    mobile: mobile,
    onGroup: _selectGroup,
    onBuilding: (b) {
      _selectBuilding(b);
      if (mobile) Navigator.of(context).pop();
    },
    onRegion: (b, r) => _selectBuilding(b, region: r),
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
                      AppSheetCloseButton(
                        tooltip: '关闭目录',
                        onPressed: () => Navigator.of(context).pop(),
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
    final points = <SavedLocation>[
      if (_level == 0) ...[
        for (final g in groups)
          if (_groupPosition(g) case final point?)
            _location(point, id: 'atlas-group:${g.id}', name: g.name),
        for (final b in buildings.where((b) => !groupIds.contains(b.groupId)))
          if (_position(b) case final point?) _location(point, name: b.name),
      ] else
        for (final b in buildings)
          if (_level >= 2 &&
              b.regions.any((r) => r.point?.source == 'region')) ...[
            for (final r in b.regions)
              if (r.point case final point? when point.source == 'region')
                _location(point),
          ] else if (_position(b) case final point?)
            _location(point, name: b.name),
    ];
    final selected = region?.point ?? building?.point;
    final story = campusStoryFor(building: building, group: group);
    final polygons = <Polygon>[
      for (final g in groups)
        if (g.vertices.length >= 3)
          Polygon(
            hitValue: g.id,
            points: [
              for (final v in g.vertices) LatLng(v.latitude, v.longitude),
            ],
            color: p.primary.withValues(alpha: g.id == _groupId ? .19 : .075),
            borderColor: p.primary.withValues(
              alpha: g.id == _groupId ? .95 : .55,
            ),
            borderStrokeWidth: g.id == _groupId ? 2.5 : 1.5,
          ),
    ];
    return LayoutBuilder(
      builder: (context, frame) {
        final desktop = {
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        }.contains(Theme.of(context).platform);
        final mobile = !desktop && frame.maxWidth < 800;
        return SubpageScaffold(
          title: '校园地图',
          body: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 0 : 24,
              mobile ? 0 : 4,
              mobile ? 0 : 24,
              mobile ? 0 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampusWorkspaceHeader(
                  campus: _campus,
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 16 : 0,
                    8,
                    mobile ? 16 : 0,
                    16,
                  ),
                  maxWidth: mobile ? double.infinity : 344,
                  onChanged: (c) {
                    _manualCampus = true;
                    _switchCampus(c);
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (!mobile) ...[
                        SizedBox(
                          key: const ValueKey('atlas-desktop-directory'),
                          width: (frame.maxWidth * .24).clamp(200.0, 280.0),
                          child: CampusDirectoryCard(child: _directory()),
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
                                bounds: campusBoundsFor(_campus),
                                minZoom: kCampusScopedMinZoom,
                                zoom: 16,
                                places: points,
                                showPlaceLabels: true,
                                avoidLabelOverlap: true,
                                initialCameraFit: _campusCameraFit(),
                                areas: polygons,
                                selectedPlaceId: _level == 0 && group != null
                                    ? 'atlas-group:${group.id}'
                                    : _level == 1 && building != null
                                    ? _position(building)?.id
                                    : selected?.id,
                                borderRadius: mobile
                                    ? BorderRadius.zero
                                    : BorderRadius.circular(AppRadii.card),
                                onZoomChanged: (zoom) {
                                  final next = zoom >= 18
                                      ? 2
                                      : zoom >= 16.5
                                      ? 1
                                      : 0;
                                  if (_level != next) {
                                    setState(() => _level = next);
                                  }
                                },
                                onPlace: (place) {
                                  if (place.id.startsWith('atlas-group:')) {
                                    _selectGroup(
                                      place.id.substring('atlas-group:'.length),
                                      moveCamera: false,
                                    );
                                    return;
                                  }
                                  for (final b in buildings) {
                                    final r = b.regions
                                        .where((r) => r.point?.id == place.id)
                                        .firstOrNull;
                                    if (r != null || b.point?.id == place.id) {
                                      _selectBuilding(
                                        b,
                                        region: r,
                                        moveCamera: false,
                                      );
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom:
                                  MapAttributionControls.footerHeight +
                                  14 +
                                  (mobile
                                      ? MediaQuery.paddingOf(context).bottom
                                      : 0),
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
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.card,
                                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          if (building != null || group != null)
                                            AppTextLink(
                                              key: const ValueKey(
                                                'atlas-open-story',
                                              ),
                                              '详情',
                                              onPressed: () => showDialog<void>(
                                                context: context,
                                                barrierColor: Colors.black
                                                    .withValues(alpha: .48),
                                                builder: (_) =>
                                                    CampusStoryDialog(
                                                      building: building,
                                                      group: group,
                                                      region: region,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      if (region != null)
                                        Text(
                                          '${building!.name}简介',
                                          style: TextStyle(
                                            color: p.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 112,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            story?.summary ??
                                                (building == null
                                                    ? group == null
                                                          ? '选择楼群或搜索楼宇，了解校园建筑'
                                                          : '这里是${group.name}所在的校园片区。相关介绍正在补充。'
                                                    : '这处建筑的校史与建筑介绍正在补充。'),
                                            style: TextStyle(
                                              color: p.muted,
                                              fontSize: 12,
                                              height: 1.6,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (mobile &&
                                          building != null &&
                                          building.regions.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                for (final r
                                                    in building.regions)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    child: AppFilterChoice(
                                                      compact: true,
                                                      label: _regionLabel(r),
                                                      selected:
                                                          _regionId == r.id,
                                                      onTap: () =>
                                                          _selectBuilding(
                                                            building,
                                                            region: r,
                                                            moveCamera: false,
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
    required this.mapSelectionRevision,
  });
  final Campus campus;
  final int mapSelectionRevision;
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
  final _buildingScroll = ScrollController();
  final _buildingKeys = <String, GlobalKey>{};
  String? _groupId;
  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
    if (widget.buildingId != null) _revealMapSelection();
  }

  void _revealMapSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _buildingKeys[widget.buildingId]?.currentContext;
      if (target == null) {
        if (widget.buildingId == null && _buildingScroll.hasClients) {
          _buildingScroll.jumpTo(0);
        }
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: .15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.fast,
        curve: AppMotion.fastCurve,
      );
    });
  }

  @override
  void didUpdateWidget(_AtlasDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _groupId = widget.groupId;
    if (oldWidget.mapSelectionRevision != widget.mapSelectionRevision) {
      // A map pick must reveal its directory entry even in the same collection
      // or while the previous search excludes that building.
      _groupId = widget.groupId;
      final building = teachingBuildings
          .where((b) => b.id == widget.buildingId)
          .firstOrNull;
      if (building == null ||
          !_matchesQuery(building, normalizeTeachingName(_search.text))) {
        _search.clear();
      }
      _revealMapSelection();
    }
  }

  bool _matchesQuery(TeachingBuilding building, String query) =>
      query.isEmpty ||
      [
        building.name,
        ...building.aliases,
        ...building.regions.expand((r) => r.aliases),
      ].any((name) => normalizeTeachingName(name).contains(query));

  @override
  void dispose() {
    _buildingScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final groups = teachingGroups
        .where((g) => '${g.campus}校区' == widget.campus.label && _mapGroup(g))
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
                  _groupId == '_all' ||
                  (_groupId == '_other'
                      ? !groupIds.contains(b.groupId)
                      : b.groupId == _groupId)) &&
              _matchesQuery(b, query),
        )
        .toList();
    final sections = <({String id, String name, int count})>[
      (id: '_all', name: '全部楼宇', count: buildings.length),
      (
        id: '_other',
        name: '其他楼宇',
        count: buildings.where((b) => !groupIds.contains(b.groupId)).length,
      ),
      for (final g in groups)
        (
          id: g.id,
          name: g.name,
          count: buildings.where((b) => b.groupId == g.id).length,
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
        : SingleChildScrollView(
            key: const ValueKey('atlas-building-list'),
            controller: _buildingScroll,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            // This bounded campus directory has tens of entries. Build their
            // actual geometry so map picks can reveal an offscreen row without
            // estimating heights, including expanded regions and text scaling.
            child: Column(
              children: [
                for (final b in visible)
                  Builder(
                    builder: (context) {
                      final active = widget.buildingId == b.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            key: _buildingKeys.putIfAbsent(b.id, GlobalKey.new),
                            padding: const EdgeInsets.only(bottom: 4),
                            child: AppHoverSurface(
                              key: ValueKey('atlas-building-${b.id}'),
                              outlined: false,
                              backgroundColor: active
                                  ? p.accentSoft
                                  : Colors.transparent,
                              hoverColor: active
                                  ? Color.alphaBlend(
                                      p.hoverOverlay,
                                      p.accentSoft,
                                    )
                                  : p.hover,
                              pressedColor: p.controlPressed,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              onTap: () => widget.onBuilding(b),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                  Icon(
                                    AppIcons.right,
                                    color: p.muted,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!widget.mobile && active)
                            for (final r in b.regions)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  bottom: 2,
                                ),
                                child: AppHoverSurface(
                                  key: ValueKey('atlas-region-${r.id}'),
                                  outlined: false,
                                  backgroundColor: widget.regionId == r.id
                                      ? p.accentSurface
                                      : Colors.transparent,
                                  hoverColor: widget.regionId == r.id
                                      ? Color.alphaBlend(
                                          p.hoverOverlay,
                                          p.accentSoft,
                                        )
                                      : p.hover,
                                  pressedColor: p.controlPressed,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.control,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  onTap: () => widget.onRegion(b, r),
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
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppSearchField(
            key: const ValueKey('atlas-search'),
            controller: _search,
            compact: true,
            inset: true,
            hintText: '搜索楼名、别名或分区',
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_groupId != null && query.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
            child: Row(
              children: [
                AppIconButton(
                  tooltip: '返回目录',
                  extent: 34,
                  onPressed: () => selectGroup(null),
                  icon: const Icon(AppIcons.back, size: 18),
                ),
                Expanded(
                  child: AppTruncatedText(
                    sections.where((s) => s.id == _groupId).firstOrNull?.name ??
                        '楼宇',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _groupId == null && query.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    for (final s in sections)
                      AppHoverSurface(
                        key: ValueKey(
                          'atlas-group-${s.id == '_all' ? 'all' : s.id}',
                        ),
                        outlined: false,
                        backgroundColor: Colors.transparent,
                        hoverColor: p.hover,
                        pressedColor: p.controlPressed,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        onTap: () => selectGroup(s.id),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTruncatedText(
                                s.name,
                                style: TextStyle(fontSize: 13, color: p.ink),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${s.count}',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, color: p.muted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(AppIcons.right, size: 15, color: p.muted),
                          ],
                        ),
                      ),
                  ],
                )
              : list,
        ),
      ],
    );
  }
}
