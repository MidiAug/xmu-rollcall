import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Controlled selection: null means mixed; activation always selects it.
class AppCheckbox extends StatefulWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final bool? value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox> {
  bool _hovered = false, _focused = false, _pressed = false;
  void _activate() => widget.onChanged?.call(widget.value != true);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = widget.onChanged != null;
    final marked = widget.value != false;
    final radius = BorderRadius.circular(4);
    return AppTooltipAnchor(
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: Semantics(
          label: widget.label,
          checked: widget.value == true,
          mixed: widget.value == null,
          enabled: enabled,
          onTap: enabled ? _activate : null,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onShowHoverHighlight: (v) => setState(() => _hovered = v),
            onShowFocusHighlight: (v) => setState(() => _focused = v),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: enabled ? _activate : null,
              onTapDown: enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppMotion.instant,
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: enabled && (_hovered || _pressed)
                            ? p.selected
                            : null,
                        borderRadius: BorderRadius.circular(7),
                        border: _focused ? Border.all(color: p.primary) : null,
                      ),
                      child: Opacity(
                        opacity: enabled ? 1 : .4,
                        child: AnimatedContainer(
                          duration: AppMotion.instant,
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: marked ? p.primary : p.surface,
                            borderRadius: radius,
                            border: Border.all(
                              color: marked
                                  ? p.primary
                                  : p.muted.withValues(alpha: .65),
                              width: 1.25,
                            ),
                          ),
                          child: marked
                              ? Center(
                                  child: widget.value == null
                                      ? Container(
                                          width: 9,
                                          height: 2,
                                          color: p.canvas,
                                        )
                                      : Icon(
                                          AppIcons.check,
                                          size: 14,
                                          color: p.canvas,
                                        ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
