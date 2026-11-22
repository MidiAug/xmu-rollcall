import 'app_service_symbol.dart';
import 'app_icon_button.dart';
import 'package:flutter/material.dart';
import 'app_glass_surface.dart';
import 'app_form_controls.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Shared dialog surface; business pages supply content, not another skin.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.insetPadding = const EdgeInsets.all(AppSpace.xl),
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: insetPadding,
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: AppGlassSurface(
        blur: 0,
        opacity: 1,
        elevated: true,
        borderRadius: BorderRadius.circular(AppRadii.dialog),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.dialog),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}

class AppNoticeDialog extends StatelessWidget {
  const AppNoticeDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
  });
  final String title, message;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => AppDialogFrame(
    maxWidth: 360,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: '关闭', onPressed: onClose),
          ),
        ],
      ),
    ),
  );
}

/// Shared confirm / prompt dialogs (Quiet Utility, not raw [AlertDialog]).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  bool destructive = false,
  bool showCloseButton = false,
  IconData? icon,
  double maxWidth = 360,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return AppDialogFrame(
        maxWidth: maxWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (icon != null) ...[
                            AppServiceSymbol(icon: icon, size: 40),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.cardTitle.copyWith(
                                color: p.ink,
                              ),
                            ),
                          ),
                          if (showCloseButton)
                            AppIconButton(
                              tooltip: '关闭',
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      kind: AppButtonKind.secondary,
                      label: cancelLabel,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: destructive
                          ? FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              overlayColor: Colors.transparent,
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (s) => s.contains(WidgetState.pressed)
                                    ? Color.lerp(p.danger, p.ink, .2)!
                                    : s.contains(WidgetState.hovered)
                                    ? Color.lerp(p.danger, p.ink, .12)!
                                    : p.danger,
                              ),
                            )
                          : null,
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}

/// Single-line text prompt (rename / note).
///
/// Controller lives inside [_AppPromptDialog] so Enter / hot-reload cannot
/// touch a disposed [TextEditingController] after [showDialog] returns.
///
/// Do **not** add [MediaQuery.viewInsets] into the dialog body padding — the
/// dialog route already shifts for the keyboard; double-counting grows the
/// panel and pushes actions off-screen (unusable until IME dismisses).
Future<String?> showAppPromptDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hintText,
  String? labelText,
  IconData? inputIcon,
  String? Function(String value)? validator,
  TextInputType? keyboardType,
  String cancelLabel = '取消',
  String confirmLabel = '保存',
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => _AppPromptDialog(
      title: title,
      message: message,
      initialValue: initialValue,
      hintText: hintText,
      labelText: labelText,
      inputIcon: inputIcon,
      validator: validator,
      keyboardType: keyboardType,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _AppPromptDialog extends StatefulWidget {
  const _AppPromptDialog({
    required this.title,
    this.message,
    this.initialValue,
    this.hintText,
    this.labelText,
    this.inputIcon,
    this.validator,
    this.keyboardType,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String? message;
  final String? initialValue;
  final String? hintText;
  final String? labelText;
  final IconData? inputIcon;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_AppPromptDialog> createState() => _AppPromptDialogState();
}

class _AppPromptDialogState extends State<_AppPromptDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    final error = widget.validator?.call(t);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppDialogFrame(
      maxWidth: 400,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.cardTitle.copyWith(color: p.ink),
                  ),
                ),
                AppIconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            if (widget.message != null && widget.message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.message!,
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(
                labelText: widget.labelText,
                fillColor: p.controlSurface,
                prefixIcon: widget.inputIcon == null
                    ? null
                    : Icon(widget.inputIcon, color: p.muted),
                hintText: widget.hintText,
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    kind: AppButtonKind.secondary,
                    label: widget.cancelLabel,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Surface and safe area for short touch tasks with caller-owned scrolling/actions.
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final EdgeInsetsGeometry padding;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppGlassSurface(
    blur: 0,
    opacity: 1,
    elevated: true,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppRadii.dialog),
    ),
    child: Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.of(context).controlRim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
