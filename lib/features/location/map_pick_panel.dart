import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// 厦门大学翔安校区（高德 GCJ-02，约 24.6084, 118.3097）。
const LatLng kDefaultMapCenter = LatLng(24.608429, 118.309669);

const String kAmapTileUrlTemplate =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

const List<String> kAmapTileSubdomains = ['1', '2', '3', '4'];

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
    this.requireNote = false,
    this.confirmLabel,
    this.initialNote = '',
    this.busy = false,
    this.contentPadding = const EdgeInsets.all(16),
    this.onDraftChanged,
    required this.onConfirm,
  });

  final LatLng? initial;
  final bool requireNote;
  final String? confirmLabel;
  final String initialNote;
  final bool busy;
  final EdgeInsets contentPadding;
  final ValueChanged<MapPickResult>? onDraftChanged;
  final ValueChanged<MapPickResult> onConfirm;

  @override
  State<MapPickPanel> createState() => MapPickPanelState();
}

class MapPickPanelState extends State<MapPickPanel> {
  late LatLng _point;
  final _mapController = MapController();
  late final TextEditingController _note;
  final _noteFocus = FocusNode();
  String? _noteError;

  LatLng get point => _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? kDefaultMapCenter;
    _note = TextEditingController(text: widget.initialNote);
  }

  Future<void> confirm() async {
    if (widget.busy) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Expanded(
              child: IgnorePointer(
                ignoring: widget.busy,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: p.surfaceHigh,
                    initialCenter: _point,
                    initialZoom: 16,
                    onTap: (_, latLng) {
                      FocusScope.of(context).unfocus();
                      setState(() => _point = latLng);
                      _draftChanged();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kAmapTileUrlTemplate,
                      subdomains: kAmapTileSubdomains,
                      userAgentPackageName: 'com.xmu.rollcall',
                    ),
                    MarkerLayer(
                      markers: [
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
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('高德地图')],
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
                        TextField(
                          key: const ValueKey('location-note-input'),
                          controller: _note,
                          focusNode: _noteFocus,
                          enabled: !widget.busy,
                          textInputAction: TextInputAction.done,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            labelText: '地点备注',
                            hintText: '例如：学武楼 301',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
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
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coord,
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
                            onPressed: widget.busy ? null : confirm,
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
