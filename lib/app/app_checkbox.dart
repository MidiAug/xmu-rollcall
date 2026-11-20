import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A labelled preference shares the same check mark as table selection. The
/// label is clickable, with only one keyboard target and one merged semantic.
class AppCheckboxRow extends StatelessWidget {
  const AppCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      children: [
        TooltipVisibility(
          visible: false,
          child: AppCheckbox(value: value, label: label, onChanged: onChanged),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onChanged == null
                        ? AppPalette.of(context).muted
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

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
    final radius = BorderRadius.circular(5);
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
            mouseCursor: WidgetStateMouseCursor.adaptiveClickable,
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
                        color: !enabled
                            ? null
                            : _pressed
                            ? p.controlPressed
                            : _hovered
                            ? p.controlHover
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
