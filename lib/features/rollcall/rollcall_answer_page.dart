import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/coord_transform.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';
import 'package:xmu_rollcall/features/rollcall/radar_place_card.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class RollcallAnswerPage extends ConsumerStatefulWidget {
  const RollcallAnswerPage({
    super.key,
    required this.item,
    this.assistUserId,
    this.previewMode = false,
  });

  final RollcallItem item;

  /// When set, submit via assist session jar / deviceId.
  final int? assistUserId;

  /// Debug-only: confirm UI without calling the rollcall API.
  final bool previewMode;

  @override
  ConsumerState<RollcallAnswerPage> createState() => _RollcallAnswerPageState();
}

class _RollcallAnswerPageState extends ConsumerState<RollcallAnswerPage> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  RadarGeoSelection? _selection;
  String? _status;
  bool _pinnedByUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCoursePref());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _syncCoursePref() {
    if (!mounted || !widget.item.isRadar || _pinnedByUser) return;
    final pref = ref
        .read(courseRadarDefaultsProvider.notifier)
        .forCourse(
          courseId: widget.item.courseId,
          courseTitle: widget.item.courseTitle,
        );
    if (pref == null) return;
    final next = selectionFromCoursePref(
      pref,
      ref.read(savedLocationsProvider),
    );
    final cur = _selection;
    if (cur != null &&
        cur.filledFrom == RadarFilledFrom.pref &&
        cur.latitude == next.latitude &&
        cur.longitude == next.longitude &&
        cur.obtainedVia == next.obtainedVia &&
        cur.placeId == next.placeId &&
        cur.label == next.label) {
      return;
    }
    setState(() => _selection = next);
  }

  void _pin(RadarGeoSelection selection) {
    setState(() {
      _pinnedByUser = true;
      _selection = selection.copyWith(filledFrom: RadarFilledFrom.user);
      _status = null;
    });
  }

  Future<bool> _confirm(String summary) {
    return showAppConfirmDialog(
      context,
      title: '确认提交签到',
      message: summary,
      confirmLabel: '确认提交',
    );
  }

  Future<void> _submitNumber() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入数字签到码')));
      return;
    }
    final opId = RollcallLog.newOpId();
    final session =
        widget.assistUserId == null ? 'owner' : 'assist';
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n类型：数字\n签到码：$code\n\n仅本人到课操作。',
    );
    if (!confirmed) {
      RollcallLog.cancel(
        opId: opId,
        type: 'number',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      return;
    }
    setState(() => _submitting = true);
    final started = DateTime.now();
    bool? ok;
    try {
      RollcallLog.start(
        opId: opId,
        type: 'number',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      RollcallLog.numberCode(opId: opId, numberCode: code);
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .answerNumber(
            rollcallId: widget.item.rollcallId,
            numberCode: code,
            opId: opId,
          );
      ok = result.ok;
      await ref
          .read(historyProvider.notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: widget.item.rollcallId,
              courseTitle: widget.item.courseTitle,
              typeLabel: '数字',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? (result.ok ? '成功' : '失败'))),
      );
      if (result.ok) Navigator.of(context).pop();
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交异常：$e')));
    } finally {
      RollcallLog.end(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        ok: ok,
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _useSystemLocation() async {
    setState(() => _status = '获取定位…');
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      RollcallLog.locationFail(
        opId: RollcallLog.newOpId(),
        reason: 'service_off',
      );
      setState(() => _status = '请打开系统定位，或改用地图选点 / 已保存地点');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      RollcallLog.locationFail(
        opId: RollcallLog.newOpId(),
        reason: 'permission_denied',
      );
      setState(() => _status = '定位权限被拒绝，可改用地图选点或已保存地点');
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      RollcallLog.locationFail(
        opId: RollcallLog.newOpId(),
        reason: 'permission_denied_forever',
      );
      setState(() => _status = '定位权限被拒绝，可改用地图选点或已保存地点');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      // Geolocator is WGS-84; Amap tiles + campus radar use GCJ-02 in China.
      final gcj = wgs84ToGcj02(pos.latitude, pos.longitude);
      _pin(
        RadarGeoSelection(
          latitude: gcj.latitude,
          longitude: gcj.longitude,
          accuracy: pos.accuracy.clamp(5, 100),
          obtainedVia: RadarObtainedVia.device,
          filledFrom: RadarFilledFrom.user,
        ),
      );
    } catch (e) {
      RollcallLog.locationFail(
        opId: RollcallLog.newOpId(),
        reason: 'position_error',
        error: e,
      );
      if (mounted) setState(() => _status = '定位失败，可改用地图选点或已保存地点');
    }
  }

  Future<void> _useMapPick() async {
    final initial = _selection == null
        ? null
        : LatLng(_selection!.latitude, _selection!.longitude);
    final result = await Navigator.of(context).push<MapPickResult>(
      AppPageRoutes.build(
        MapPickPage(initial: initial, title: '选择位置'),
      ),
    );
    if (result == null || !mounted) return;
    final note = result.saveNote?.trim() ?? '';
    if (note.isNotEmpty) {
      final place = await ref
          .read(savedLocationsProvider.notifier)
          .add(
            note: note,
            latitude: result.latitude,
            longitude: result.longitude,
          );
      if (!mounted) return;
      _pin(
        RadarGeoSelection(
          latitude: place.latitude,
          longitude: place.longitude,
          accuracy: place.accuracy,
          obtainedVia: RadarObtainedVia.place,
          placeId: place.id,
          label: place.note,
          filledFrom: RadarFilledFrom.user,
        ),
      );
      return;
    }
    _pin(
      RadarGeoSelection(
        latitude: result.latitude,
        longitude: result.longitude,
        accuracy: 35,
        obtainedVia: RadarObtainedVia.map,
        filledFrom: RadarFilledFrom.user,
      ),
    );
  }

  Future<void> _usePreset() async {
    final list = ref.read(savedLocationsProvider);
    final picked = await pickSavedLocation(context, list);
    if (picked == null || !mounted) return;
    _pin(picked);
  }

  Future<void> _changeLocation() async {
    final action = await showRadarLocationSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case RadarLocationAction.device:
        await _useSystemLocation();
      case RadarLocationAction.map:
        await _useMapPick();
      case RadarLocationAction.preset:
        await _usePreset();
    }
  }

  Future<void> _submitRadar() async {
    final sel = _selection;
    if (sel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择位置')));
      return;
    }
    final opId = RollcallLog.newOpId();
    final session =
        widget.assistUserId == null ? 'owner' : 'assist';
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n'
      '${sel.confirmLine}\n'
      '${sel.latitude.toStringAsFixed(5)}, ${sel.longitude.toStringAsFixed(5)}'
      '${widget.previewMode ? "\n\n（预览模式，不会提交到服务器）" : ""}',
    );
    if (!confirmed) {
      RollcallLog.cancel(
        opId: opId,
        type: 'radar',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      return;
    }
    if (!mounted) return;

    if (widget.previewMode) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预览模式：未向服务器提交')));
      return;
    }

    setState(() => _submitting = true);
    final started = DateTime.now();
    bool? ok;
    try {
      RollcallLog.start(
        opId: opId,
        type: 'radar',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      final source = switch (sel.obtainedVia) {
        RadarObtainedVia.device => 'system',
        RadarObtainedVia.map => 'map',
        RadarObtainedVia.place => 'preset',
      };
      RollcallLog.location(
        opId: opId,
        source: source,
        latitude: sel.latitude,
        longitude: sel.longitude,
        accuracyM: sel.accuracy.clamp(5, 100),
      );
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .answerRadar(
            rollcallId: widget.item.rollcallId,
            latitude: sel.latitude,
            longitude: sel.longitude,
            accuracy: sel.accuracy.clamp(5, 100),
            opId: opId,
          );
      ok = result.ok;
      await ref
          .read(historyProvider.notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: widget.item.rollcallId,
              courseTitle: widget.item.courseTitle,
              typeLabel: '雷达',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? (result.ok ? '成功' : '失败'))),
      );
      if (result.ok) {
        await ref
            .read(courseRadarDefaultsProvider.notifier)
            .rememberSuccess(
              courseTitle: widget.item.courseTitle,
              courseId: widget.item.courseId,
              latitude: sel.latitude,
              longitude: sel.longitude,
              accuracy: sel.accuracy,
              placeId: sel.placeId,
              obtainedVia: sel.obtainedVia,
              labelSnapshot: sel.label,
            );
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _status = '${result.message ?? "提交失败"}。可更换位置后重试。';
        });
      }
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交异常：$e')));
    } finally {
      RollcallLog.end(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        ok: ok,
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = AppPalette.of(context);
    ref.listen(savedLocationsProvider, (_, _) => _syncCoursePref());
    ref.listen(courseRadarDefaultsProvider, (_, _) => _syncCoursePref());

    return SubpageScaffold(
      title: widget.previewMode ? '雷达签到（预览）' : '${item.typeLabel}签到',
      body: AppContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppSpace.md,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
            Text(
              item.courseTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
                color: p.ink,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '发起人：${item.createdByName}',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            if (widget.previewMode) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                '开发预览：不调用签到 API',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            if (item.isNumber) ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '数字签到码',
                  hintText: '老师口述的码',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton(
                onPressed: _submitting ? null : _submitNumber,
                child: Text(_submitting ? '提交中…' : '确认并提交'),
              ),
            ] else if (item.isRadar) ...[
              RadarPlaceCard(
                selection: _selection,
                onChange: _submitting ? null : _changeLocation,
              ),
              if (_status != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_submitting || _selection == null)
                      ? null
                      : _submitRadar,
                  child: Text(
                    _submitting
                        ? '提交中…'
                        : (widget.previewMode ? '预览确认' : '用此位置签到'),
                  ),
                ),
              ),
            ] else
              const Text('暂不支持此签到类型'),
          ],
        ),
      ),
    );
  }
}
