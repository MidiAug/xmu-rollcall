import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  Position? _position;
  String? _status;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() => _status = '获取定位…');
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      setState(() => _status = '请打开系统定位服务');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _status = '定位权限被拒绝');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    setState(() {
      _position = pos;
      _status =
          '当前位置：${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
          '（精度 ${pos.accuracy.toStringAsFixed(0)} m）';
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

  Future<void> _submitRadar() async {
    final pos = _position;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先获取定位')),
      );
      return;
    }
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n类型：雷达\n'
      '纬度：${pos.latitude.toStringAsFixed(6)}\n'
      '经度：${pos.longitude.toStringAsFixed(6)}\n'
      '精度：${pos.accuracy.toStringAsFixed(0)} m\n\n'
      '将使用系统定位坐标提交（非假坐标代签）。',
    );
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(rollcallRepositoryProvider).answerRadar(
            rollcallId: widget.item.rollcallId,
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy.clamp(5, 100),
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text('${item.typeLabel}签到')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(item.courseTitle, style: Theme.of(context).textTheme.titleLarge),
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
            FilledButton.tonal(
              onPressed: _submitting ? null : _loadLocation,
              child: const Text('获取当前位置'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submitRadar,
              child: Text(_submitting ? '提交中…' : '确认并提交定位'),
            ),
          ] else
            const Text('暂不支持此签到类型'),
        ],
      ),
    );
  }
}
