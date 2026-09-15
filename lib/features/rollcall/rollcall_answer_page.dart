import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class RollcallAnswerPage extends ConsumerStatefulWidget {
  const RollcallAnswerPage({super.key, required this.item});

  final RollcallItem item;

  @override
  ConsumerState<RollcallAnswerPage> createState() => _RollcallAnswerPageState();
}

class _RollcallAnswerPageState extends ConsumerState<RollcallAnswerPage> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  RadarGeoSelection? _selection;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyCourseDefault());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _applyCourseDefault() {
    if (!widget.item.isRadar) return;
    final def = ref
        .read(courseRadarDefaultsProvider.notifier)
        .forCourse(widget.item.courseTitle);
    if (def == null) return;
    setState(() {
      _selection = RadarGeoSelection(
        latitude: def.latitude,
        longitude: def.longitude,
        accuracy: def.accuracy,
        sourceLabel: def.note.isEmpty ? '本课上次成功点' : '本课上次成功点（${def.note}）',
      );
      _status =
          '已预填本课上次成功坐标：${def.latitude.toStringAsFixed(5)}, '
          '${def.longitude.toStringAsFixed(5)}';
    });
  }

  Future<bool> _confirm(String summary) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认提交签到'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submitNumber() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入数字签到码')),
      );
      return;
    }
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n类型：数字\n签到码：$code\n\n仅本人到课操作。',
    );
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(rollcallRepositoryProvider).answerNumber(
            rollcallId: widget.item.rollcallId,
            numberCode: code,
          );
      await ref.read(historyProvider.notifier).add(
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交异常：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _useSystemLocation() async {
    setState(() => _status = '获取定位…');
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      setState(() => _status = '请打开系统定位服务，或改用地图/预设点');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _status = '定位权限被拒绝，可改用地图选点或预设');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    setState(() {
      _selection = RadarGeoSelection(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy.clamp(5, 100),
        sourceLabel: '系统定位',
      );
      _status =
          '系统定位：${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
          '（精度 ${pos.accuracy.toStringAsFixed(0)} m）';
    });
  }

  Future<void> _useMapPick() async {
    final initial = _selection == null
        ? null
        : LatLng(_selection!.latitude, _selection!.longitude);
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => MapPickPage(
          initial: initial,
          title: '选择位置',
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.saveNote != null) {
      await ref.read(savedLocationsProvider.notifier).add(
            note: result.saveNote!,
            latitude: result.latitude,
            longitude: result.longitude,
          );
    }
    setState(() {
      _selection = RadarGeoSelection(
        latitude: result.latitude,
        longitude: result.longitude,
        accuracy: 35,
        sourceLabel: result.saveNote != null ? result.saveNote! : '地图',
      );
      _status = null;
    });
  }

  Future<void> _usePreset() async {
    final list = ref.read(savedLocationsProvider);
    final picked = await pickSavedLocation(context, list);
    if (picked == null || !mounted) return;
    setState(() {
      _selection = picked;
      _status =
          '${picked.sourceLabel}：${picked.latitude.toStringAsFixed(5)}, '
          '${picked.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _submitRadar() async {
    final sel = _selection;
    if (sel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择位置（系统 / 地图 / 预设）')),
      );
      return;
    }
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n'
      '${sel.sourceLabel}\n'
      '${sel.latitude.toStringAsFixed(5)}, ${sel.longitude.toStringAsFixed(5)}',
    );
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(rollcallRepositoryProvider).answerRadar(
            rollcallId: widget.item.rollcallId,
            latitude: sel.latitude,
            longitude: sel.longitude,
            accuracy: sel.accuracy.clamp(5, 100),
          );
      await ref.read(historyProvider.notifier).add(
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
        await ref.read(courseRadarDefaultsProvider.notifier).rememberSuccess(
              courseTitle: widget.item.courseTitle,
              latitude: sel.latitude,
              longitude: sel.longitude,
              accuracy: sel.accuracy,
              note: sel.sourceLabel,
            );
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _status =
              '${result.message ?? "提交失败"}。可换系统定位 / 地图 / 预设后重试。';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交异常：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = AppPalette.of(context);
    final presets = ref.watch(savedLocationsProvider);

    return SubpageScaffold(
      title: '${item.typeLabel}签到',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                item.courseTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '发起人：${item.createdByName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (item.isNumber) ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '数字签到码',
                    hintText: '老师口述的码',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submitNumber,
                  child: Text(_submitting ? '提交中…' : '确认并提交'),
                ),
              ] else if (item.isRadar) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: _submitting ? null : _useSystemLocation,
                      child: const Text('定位'),
                    ),
                    FilledButton.tonal(
                      onPressed: _submitting ? null : _useMapPick,
                      child: const Text('地图'),
                    ),
                    FilledButton.tonal(
                      onPressed: _submitting ? null : _usePreset,
                      child: Text(
                        '预设${presets.isEmpty ? "" : " (${presets.length})"}',
                      ),
                    ),
                  ],
                ),
                if (_selection != null) ...[
                  const SizedBox(height: 16),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selection!.sourceLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_selection!.latitude.toStringAsFixed(5)}, '
                          '${_selection!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submitRadar,
                  child: Text(_submitting ? '提交中…' : '提交'),
                ),
              ] else
                const Text('暂不支持此签到类型'),
            ],
          ),
        ),
      ),
    );
  }
}
