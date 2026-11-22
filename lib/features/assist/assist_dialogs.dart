import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Import assist identity. Controllers live in [State] (not outside [StatefulBuilder])
/// and we never pad with [MediaQuery.viewInsets] — see R-19.
Future<void> showAssistImportDialog(
  BuildContext context, {
  required Future<void> Function(String token) onImportToken,
  required Future<void> Function(String username, String password)
  onImportPlain,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => _AssistImportDialog(
      onImportToken: onImportToken,
      onImportPlain: onImportPlain,
    ),
  );
}

enum _ImportMode { token, plain }

class _AssistImportDialog extends StatefulWidget {
  const _AssistImportDialog({
    required this.onImportToken,
    required this.onImportPlain,
  });

  final Future<void> Function(String token) onImportToken;
  final Future<void> Function(String username, String password) onImportPlain;

  @override
  State<_AssistImportDialog> createState() => _AssistImportDialogState();
}

class _AssistImportDialogState extends State<_AssistImportDialog> {
  final _tokenCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _mode = _ImportMode.token;
  var _submitting = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      if (_mode == _ImportMode.token) {
        await widget.onImportToken(_tokenCtrl.text.trim());
      } else {
        await widget.onImportPlain(_userCtrl.text.trim(), _passCtrl.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.show(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppDialogFrame(
      maxWidth: 440,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '导入协助身份',
                      style: AppTypography.cardTitle.copyWith(color: p.ink),
                    ),
                  ),
                  AppSheetCloseButton(enabled: !_submitting),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              AppSegmentedControl<_ImportMode>(
                expanded: true,
                enabled: !_submitting,
                segments: const [
                  AppSegment(value: _ImportMode.token, label: '协助码'),
                  AppSegment(value: _ImportMode.plain, label: '学号密码'),
                ],
                value: _mode,
                onChanged: (value) => setState(() => _mode = value),
              ),
              const SizedBox(height: 12),
              if (_mode == _ImportMode.token) ...[
                Text(
                  '粘贴同学发来的协助码（以 xmu2. 开头）。',
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tokenCtrl,
                  maxLines: 4,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: p.insetSurface,
                    labelText: '协助码',
                    hintText: 'xmu2.…',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      _mode == _ImportMode.token &&
                          (v == null || v.trim().isEmpty)
                      ? '请粘贴协助码'
                      : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    kind: AppButtonKind.secondary,
                    onPressed: _submitting
                        ? null
                        : () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final text = data?.text;
                            if (text != null && text.isNotEmpty) {
                              _tokenCtrl.text = text;
                            }
                          },
                    label: '从剪贴板粘贴',
                  ),
                ),
              ] else ...[
                Text(
                  '输入同学学号和密码，验证后加入名单。',
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userCtrl,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '学号'),
                  validator: (v) =>
                      _mode == _ImportMode.plain &&
                          (v == null || v.trim().isEmpty)
                      ? '请输入学号'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  enabled: !_submitting,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: '密码'),
                  validator: (v) =>
                      _mode == _ImportMode.plain && (v == null || v.isEmpty)
                      ? '请输入密码'
                      : null,
                ),
              ],
              const SizedBox(height: 18),
              _AssistDialogActions(
                label: _submitting ? '正在导入…' : '导入',
                busy: _submitting,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Export assist token: pick kind, then export (no credential form).
Future<void> showAssistExportDialog(
  BuildContext context, {
  required Future<String> Function(AssistExportKind kind) export,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => _AssistExportDialog(export: export),
  );
}

class _AssistExportDialog extends StatefulWidget {
  const _AssistExportDialog({required this.export});

  final Future<String> Function(AssistExportKind kind) export;

  @override
  State<_AssistExportDialog> createState() => _AssistExportDialogState();
}

class _AssistExportDialogState extends State<_AssistExportDialog> {
  var _kind = AssistExportKind.session;
  var _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final sealed = await widget.export(_kind);
      await Clipboard.setData(ClipboardData(text: sealed));
      if (!mounted) return;
      AppToast.show(context, '已复制到剪贴板');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.show(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppDialogFrame(
      maxWidth: 440,
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
                    '导出协助码',
                    style: AppTypography.cardTitle.copyWith(color: p.ink),
                  ),
                ),
                AppSheetCloseButton(enabled: !_submitting),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            AppSegmentedControl<AssistExportKind>(
              expanded: true,
              enabled: !_submitting,
              segments: const [
                AppSegment(value: AssistExportKind.session, label: '临时会话'),
                AppSegment(value: AssistExportKind.account, label: '账号密码'),
              ],
              value: _kind,
              onChanged: (value) => setState(() => _kind = value),
            ),
            const SizedBox(height: 12),
            Panel(
              inset: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppServiceSymbol(icon: AppIcons.rollcall, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _kind == AssistExportKind.session
                          ? '把当前登录状态做成协助码发给同学。过期后需重新导出，或改用「账号密码」。仅发送给信任的人。'
                          : '将使用本机保存的学号与密码生成协助码，对方可长期代为登录；你改密码或退出登录后需重新导出。仅发送给信任的人。',
                      style: AppTypography.body.copyWith(color: p.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _AssistDialogActions(
              label: _submitting ? '正在导出…' : '导出并复制',
              busy: _submitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistDialogActions extends StatelessWidget {
  const _AssistDialogActions({
    required this.label,
    required this.busy,
    required this.onSubmit,
  });
  final String label;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final height = AppMobileUi.useTouchChrome(context)
        ? AppMobileUi.target
        : AppDensity.controlHeight(context);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.sm,
      runSpacing: AppSpace.xs,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: AppButton(
            label: '取消',
            kind: AppButtonKind.secondary,
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: AppButton(label: label, busy: busy, onPressed: onSubmit),
        ),
      ],
    );
  }
}
