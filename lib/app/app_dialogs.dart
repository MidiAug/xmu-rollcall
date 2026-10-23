import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Shared confirm / prompt dialogs (Quiet Utility, not raw [AlertDialog]).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: BorderSide(color: p.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: p.ink,
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: destructive
                            ? FilledButton.styleFrom(
                                backgroundColor: p.danger,
                                foregroundColor: Colors.white,
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
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
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.cancelLabel),
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
      ),
    );
  }
}
