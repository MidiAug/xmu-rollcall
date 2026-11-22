import 'package:flutter/material.dart';
import 'app_icon_button.dart';
import 'chrome.dart' show AppControlStyle;
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
    this.compact = false,
    this.inline = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final AppButtonKind kind;
  final bool compact;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final action = busy ? null : onPressed;
    final style = inline
        ? AppControlStyle.inlineOutlined(context)
        : compact
        ? ButtonStyle(
            minimumSize: WidgetStatePropertyAll(
              Size(0, AppDensity.controlHeight(context)),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          SizedBox.square(
            dimension: 16,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.fast,
              child: busy
                  ? CircularProgressIndicator(
                      key: const ValueKey('button-busy'),
                      strokeWidth: 1.6,
                      semanticsLabel: '$label，正在处理',
                    )
                  : Icon(icon, key: ValueKey(icon), size: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          // A text-only action has no leading slot. Replace its label in place
          // while busy rather than inserting an icon and moving its neighbours.
          child: icon != null
              ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility(
                      visible: !busy,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (busy)
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          semanticsLabel: '$label，正在处理',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
    return switch (kind) {
      AppButtonKind.primary => FilledButton(
        style: style,
        onPressed: action,
        child: content,
      ),
      AppButtonKind.secondary => OutlinedButton(
        style: style,
        onPressed: action,
        child: content,
      ),
      AppButtonKind.quiet => TextButton(
        style: style,
        onPressed: action,
        child: content,
      ),
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
    this.compact = false,
    this.inset = false,
  });
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool compact;
  final bool inset;

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
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final touch = AppDensity.isTouch(context);
    final height = touch
        ? (widget.compact ? 40.0 : 44.0)
        : AppDensity.controlHeight(context);
    final iconWidth = touch ? 40.0 : 36.0;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: touch ? (widget.compact ? 14 : 15) : 13,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: widget.inset ? p.insetSurface : null,
          isDense: true,
          constraints: BoxConstraints(minHeight: height),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: touch ? (widget.compact ? 9 : 11) : 7,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: iconWidth,
            minHeight: height,
          ),
          suffixIconConstraints: BoxConstraints(
            minWidth: iconWidth,
            minHeight: height,
          ),
          hintText: widget.hintText,
          prefixIcon: const Icon(AppIcons.search, size: 17),
          suffixIcon: value.text.isEmpty
              ? null
              : AppIconButton(
                  extent: height,
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
}
