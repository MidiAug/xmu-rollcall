import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A fixed-size thumb slides across the capsule without a pointer halo.
class AppSwitch extends StatefulWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 240);
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.value ? 1 : 0,
  );
  bool _focused = false, _pressed = false;

  void _settle() {
    final target = widget.value ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
    } else {
      _position.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void didUpdateWidget(AppSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        (oldWidget.onChanged == null) != (widget.onChanged == null)) {
      _settle();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _settle();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final palette = AppPalette.of(context);
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: WidgetStateMouseCursor.adaptiveClickable,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? _toggle : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onHorizontalDragStart: enabled ? (_) => _position.stop() : null,
          onHorizontalDragUpdate: enabled
              ? (details) {
                  _position.value += details.delta.dx / 16 * (rtl ? -1 : 1);
                }
              : null,
          onHorizontalDragEnd: enabled
              ? (details) {
                  setState(() => _pressed = false);
                  final velocity =
                      (details.primaryVelocity ?? 0) * (rtl ? -1 : 1);
                  final value = velocity.abs() > 100
                      ? velocity > 0
                      : _position.value >= .5;
                  if (value != widget.value) widget.onChanged?.call(value);
                  _settle();
                }
              : null,
          onHorizontalDragCancel: enabled
              ? () {
                  setState(() => _pressed = false);
                  _settle();
                }
              : null,
          child: SizedBox(
            width: 54,
            height: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final progress = _position.value;
                  return Opacity(
                    opacity: enabled ? 1 : .45,
                    child: Container(
                      width: 44,
                      height: 28,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          palette.ink.withValues(
                            alpha: enabled && _pressed ? .10 : 0,
                          ),
                          Color.lerp(
                            palette.surfaceHigh,
                            palette.primary,
                            progress,
                          )!,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        // Draw focus outside the track: a primary-on-primary
                        // inner border disappears when the switch is selected.
                        boxShadow: _focused
                            ? [
                                BoxShadow(
                                  color: palette.focus,
                                  spreadRadius: 3.5,
                                ),
                                BoxShadow(
                                  color: palette.canvas,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Align(
                        alignment: Alignment(
                          (rtl ? -1 : 1) * (progress * 2 - 1),
                          0,
                        ),
                        child: Container(
                          key: const ValueKey('app-switch-thumb'),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              palette.muted,
                              Colors.white,
                              progress,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
