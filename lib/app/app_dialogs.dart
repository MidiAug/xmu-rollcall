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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
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
                    color: p.ink,
                  ),
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
  String cancelLabel = '取消',
  String confirmLabel = '保存',
}) async {
  final ctrl = TextEditingController(text: initialValue ?? '');
  final result = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) {
      final p = AppPalette.of(ctx);
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
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: hintText,
                  ),
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isNotEmpty) Navigator.pop(ctx, t);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final t = ctrl.text.trim();
                          if (t.isEmpty) return;
                          Navigator.pop(ctx, t);
                        },
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
  ctrl.dispose();
  return result;
}
