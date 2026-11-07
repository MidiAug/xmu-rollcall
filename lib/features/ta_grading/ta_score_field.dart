import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A lazy roster cell owns its editor; drafts live in the page across scrolling.
class TaScoreField extends StatefulWidget {
  const TaScoreField({
    super.key,
    required this.value,
    required this.hint,
    required this.name,
    required this.enabled,
    required this.saving,
    this.readOnlyReason,
    required this.onChanged,
    required this.onSubmitted,
  });
  final String value, hint, name;
  final bool enabled, saving;
  final String? readOnlyReason;
  final ValueChanged<String> onChanged, onSubmitted;

  @override
  State<TaScoreField> createState() => _TaScoreFieldState();
}

class _TaScoreFieldState extends State<TaScoreField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  @override
  void didUpdateWidget(TaScoreField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reason = widget.readOnlyReason;
    if (reason != null && !widget.saving) {
      final display = widget.value.isEmpty ? widget.hint : widget.value;
      return Semantics(
        label: '${widget.name}的成绩',
        value: display,
        hint: reason,
        readOnly: true,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.value.isEmpty ? p.muted : p.ink,
                ),
              ),
              if (display != reason)
                Text(reason, style: TextStyle(fontSize: 11, color: p.muted)),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: '${widget.name}的成绩',
      hint: widget.saving
          ? '正在保存'
          : widget.enabled
          ? '输入后按回车保存'
          : '暂时不可编辑',
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        readOnly: !widget.enabled || widget.saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        style: TextStyle(fontSize: 13, color: AppPalette.of(context).ink),
        decoration: InputDecoration(
          hintText: widget.hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 24,
            height: 24,
          ),
          suffixIcon: widget.saving
              ? const Padding(
                  padding: EdgeInsets.all(5),
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : null,
        ),
        onChanged: widget.onChanged,
        // Retain the editor's focus after Enter, including validation failures.
        onEditingComplete: () {},
        onSubmitted: widget.enabled && !widget.saving
            ? widget.onSubmitted
            : null,
      ),
    );
  }
}
