import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';

/// Edit both daily boundaries together; the caller persists only a confirmed pair.
Future<DetectionWindow?> showDetectionWindowEditor(
  BuildContext context,
  DetectionWindow window, {
  bool focusStart = true,
}) => showDialog<DetectionWindow>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .4),
  builder: (_) => _WindowEditor(window: window, focusStart: focusStart),
);

class _WindowEditor extends StatefulWidget {
  const _WindowEditor({required this.window, required this.focusStart});
  final DetectionWindow window;
  final bool focusStart;
  @override
  State<_WindowEditor> createState() => _WindowEditorState();
}

class _WindowEditorState extends State<_WindowEditor> {
  late final _fields = [
    for (final value in [
      widget.window.startMinute,
      widget.window.endMinute,
    ]) ...[
      TextEditingController(text: (value ~/ 60).toString().padLeft(2, '0')),
      TextEditingController(text: (value % 60).toString().padLeft(2, '0')),
    ],
  ];
  String? _error;

  int? _minute(int index) {
    final hour = int.tryParse(_fields[index].text);
    final minute = int.tryParse(_fields[index + 1].text);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  void _confirm() {
    final start = _minute(0), end = _minute(2);
    if (start == null || end == null || start == end) {
      setState(
        () => _error = start == null || end == null
            ? '请输入有效时间：小时 00–23，分钟 00–59'
            : '开始和结束时间不能相同',
      );
      return;
    }
    Navigator.pop(
      context,
      DetectionWindow(
        enabled: widget.window.enabled,
        startMinute: start,
        endMinute: end,
      ),
    );
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _timeRow(String title, int index) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.content,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var part = 0; part < 2; part++) ...[
                if (part == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(fontSize: 24, color: p.muted),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    key: ValueKey('window-time-${index + part}'),
                    controller: _fields[index + part],
                    autofocus: widget.focusStart
                        ? index + part == 0
                        : index + part == 2,
                    keyboardType: TextInputType.number,
                    textInputAction: index + part == 3
                        ? TextInputAction.done
                        : TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: part == 0 ? '时' : '分',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: true,
                      fillColor: p.surface,
                    ),
                    onTap: () =>
                        _fields[index + part].selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _fields[index + part].text.length,
                        ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) {
                      if (index + part == 3) {
                        _confirm();
                      } else {
                        FocusScope.of(context).nextFocus();
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final start = _minute(0), end = _minute(2);
    final summary = start == null || end == null || start == end
        ? '使用 24 小时制，设置每天允许检测的时段'
        : '每天 ${DetectionWindow.formatMinute(start)} 至${start > end ? '次日' : ''} ${DetectionWindow.formatMinute(end)}';
    return Dialog(
      elevation: 0,
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: p.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '生效时间',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _timeRow('开始时间', 0),
              const SizedBox(height: 12),
              _timeRow('结束时间', 2),
              const SizedBox(height: 16),
              Text(
                _error ?? summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: _error == null ? p.muted : p.danger,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirm,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
