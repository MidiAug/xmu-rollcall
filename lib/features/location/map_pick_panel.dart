import 'campus_map_config.dart';
import 'location_models.dart';
import 'campus_places.dart';
import 'campus_map.dart' show CampusSelector, MapAttributionControls;
import 'place_matching.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

class MapPickResult {
  const MapPickResult({
    required this.latitude,
    required this.longitude,
    this.saveNote,
  });

  final double latitude;
  final double longitude;
  final String? saveNote;
}

/// Reusable map picker body (embed in pages; no own chrome).
class MapPickPanel extends StatefulWidget {
  const MapPickPanel({
    super.key,
    this.initial,
    this.initialCampus = Campus.xiangan,
    this.requireNote = false,
    this.confirmLabel,
    this.initialNote = '',
    this.busy = false,
    this.requireSelection = false,
    this.showCoordinates = true,
    this.selectedLabel,
    this.contentPadding = const EdgeInsets.all(16),
    this.campusSelectorPadding = const EdgeInsets.all(8),
    this.onDraftChanged,
    required this.onConfirm,
  });

  final LatLng? initial;
  final Campus initialCampus;
  final bool requireSelection;
  final bool showCoordinates;
  final String? selectedLabel;
  final bool requireNote;
  final String? confirmLabel;
  final String initialNote;
  final bool busy;
  final EdgeInsets contentPadding;
  final EdgeInsets campusSelectorPadding;
  final ValueChanged<MapPickResult>? onDraftChanged;
  final ValueChanged<MapPickResult> onConfirm;

  @override
  State<MapPickPanel> createState() => MapPickPanelState();
}

class MapPickPanelState extends State<MapPickPanel>
    with WidgetsBindingObserver {
  late LatLng _point;
  final _mapController = MapController();
  late final TextEditingController _note;
  final _noteFocus = FocusNode();
  final _noteField = GlobalKey();
  String? _noteError;
  Campus _campus = Campus.xiangan;
  bool _hasSelection = false;
  bool _campusChosen = false;

  LatLng get point => _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? widget.initialCampus.center;
    _hasSelection = widget.initial != null;
    _note = TextEditingController(text: widget.initialNote);
    _campus =
        campusForPoint(
          SavedLocation(
            id: '',
            note: '',
            latitude: _point.latitude,
            longitude: _point.longitude,
            createdAt: DateTime.now(),
          ),
        ) ??
        Campus.xiangan;
    WidgetsBinding.instance.addObserver(this);
    _noteFocus.addListener(_revealNote);
  }

  @override
  void didUpdateWidget(MapPickPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The cached student profile may resolve after the dialog's first frame.
    if (widget.initialCampus != oldWidget.initialCampus &&
        widget.initial == null &&
        !_hasSelection &&
        !_campusChosen) {
      _campus = widget.initialCampus;
      _point = _campus.center;
      _mapController.move(_point, 16);
    }
  }

  @override
  void didChangeMetrics() => _revealNote();

  void _revealNote() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _noteField.currentContext;
      if (!mounted || !_noteFocus.hasFocus || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 180),
      );
    });
  }

  Future<void> confirm() async {
    if (widget.busy || (widget.requireSelection && !_hasSelection)) return;
    final saveNote = widget.requireNote ? _note.text.trim() : null;
    if (widget.requireNote && saveNote!.isEmpty) {
      setState(() => _noteError = '请填写地点备注');
      _noteFocus.requestFocus();
      return;
    }

    if (!mounted) return;
    widget.onConfirm(
      MapPickResult(
        latitude: _point.latitude,
        longitude: _point.longitude,
        saveNote: saveNote,
      ),
    );
  }

  void _draftChanged() => widget.onDraftChanged?.call(
    MapPickResult(
      latitude: _point.latitude,
      longitude: _point.longitude,
      saveNote: _note.text,
    ),
  );

  @override
  void dispose() {
    _mapController.dispose();
    _note.dispose();
    _noteFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellTabExitGuard(
      hasUnsavedChanges: () {
        final initial = widget.initial ?? widget.initialCampus.center;
        return _point.latitude != initial.latitude ||
            _point.longitude != initial.longitude ||
            _note.text.trim() != widget.initialNote.trim();
      },
      isBusy: () => widget.busy,
      child: _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final p = AppPalette.of(context);
    final coord =
        '${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}';
    final label = widget.confirmLabel ?? (widget.requireNote ? '保存' : '完成');

    return LayoutBuilder(
      builder: (context, bounds) {
        final minHeight =
            (widget.requireNote ? 300.0 : 160.0) *
            MediaQuery.textScalerOf(context).scale(1);
        final panel = Column(
          children: [
            Padding(
              padding: widget.campusSelectorPadding,
              child: CampusSelector(
                value: _campus,
                onChanged: (campus) {
                  if (widget.busy) return;
                  setState(() {
                    _campus = campus;
                    _campusChosen = true;
                    _point = campus.center;
                    _hasSelection = false;
                  });
                  _mapController.move(campus.center, 16);
                  _draftChanged();
                },
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: widget.busy,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        backgroundColor: p.surfaceHigh,
                        initialCenter: _point,
                        initialZoom: 16,
                        minZoom: kXmuMapMinZoom,
                        maxZoom: kAmapMaxZoom,
                        cameraConstraint: CameraConstraint.containCenter(
                          bounds: kXmuMapBounds,
                        ),
                        onTap: (_, latLng) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _point = latLng;
                            _hasSelection = true;
                          });
                          _draftChanged();
                        },
                      ),
                      children: [
                        TileLayer(
                          maxNativeZoom: kAmapMaxNativeZoom,
                          minNativeZoom: 3,
                          urlTemplate: kAmapTileUrlTemplate,
                          subdomains: kAmapTileSubdomains,
                          userAgentPackageName: 'com.xmu.rollcall',
                        ),
                        MarkerLayer(
                          markers: [
                            if (!widget.requireSelection || _hasSelection)
                              Marker(
                                point: _point,
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: Icon(
                                  Icons.location_on,
                                  color: p.primary,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Positioned(
                      top: kMapOverlayInset,
                      right: kMapOverlayInset,
                      child: MapAttributionControls(),
                    ),
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: p.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: widget.contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.requireNote) ...[
                        KeyedSubtree(
                          key: _noteField,
                          child: TextField(
                            key: const ValueKey('location-note-input'),
                            controller: _note,
                            focusNode: _noteFocus,
                            enabled: !widget.busy,
                            textInputAction: TextInputAction.done,
                            style: Theme.of(context).textTheme.bodyMedium,
                            decoration: InputDecoration(
                              labelText: '地点备注',
                              hintText: '例如：学武楼 301',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              errorText: _noteError,
                            ),
                            onChanged: (_) {
                              if (_noteError != null) {
                                setState(() => _noteError = null);
                              }
                              _draftChanged();
                            },
                            onSubmitted: (_) => confirm(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.requireSelection && !_hasSelection
                                  ? '点击地图选择位置'
                                  : widget.showCoordinates
                                  ? coord
                                  : _hasSelection
                                  ? (widget.selectedLabel?.isNotEmpty == true
                                        ? widget.selectedLabel!
                                        : '已选择位置')
                                  : '点击地图选择位置',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: p.muted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed:
                                widget.busy ||
                                    (widget.requireSelection && !_hasSelection)
                                ? null
                                : confirm,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        if (bounds.maxHeight < minHeight) {
          return SingleChildScrollView(
            child: SizedBox(height: minHeight, child: panel),
          );
        }
        return panel;
      },
    );
  }
}
