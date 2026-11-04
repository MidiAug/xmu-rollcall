import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

enum AppButtonKind { primary, secondary, quiet }

/// Labels, optional symbols and progress share one size and state contract.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.kind = AppButtonKind.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final AppButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final action = busy ? null : onPressed;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy || icon != null) ...[
          if (busy)
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            )
          else
            Icon(icon, size: 16),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    return switch (kind) {
      AppButtonKind.primary => FilledButton(onPressed: action, child: content),
      AppButtonKind.secondary => OutlinedButton(
        onPressed: action,
        child: content,
      ),
      AppButtonKind.quiet => TextButton(onPressed: action, child: content),
    };
  }
}

/// Shared search field retains Flutter editing/IME behavior and adds a clear
/// action only when it is useful. Clearing invokes the same query callback.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _owned;
  TextEditingController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _owned = TextEditingController();
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && _owned == null) {
      _owned = TextEditingController(text: oldWidget.controller?.text);
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(AppIcons.search, size: 17),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    icon: const Icon(AppIcons.close, size: 13),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                  ),
          ),
        ),
      );
}
