import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_rollcall_hub_page.dart';

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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '导入协助身份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<_ImportMode>(
                  segments: const [
                    ButtonSegment(
                      value: _ImportMode.token,
                      label: Text('协助码'),
                      icon: Icon(Icons.link, size: 16),
                    ),
                    ButtonSegment(
                      value: _ImportMode.plain,
                      label: Text('学号密码'),
                      icon: Icon(Icons.password, size: 16),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _submitting
                      ? null
                      : (s) => setState(() => _mode = s.first),
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
                    decoration: const InputDecoration(
                      labelText: '协助码',
                      hintText: 'xmu2.…',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => _mode == _ImportMode.token &&
                            (v == null || v.trim().isEmpty)
                        ? '请粘贴协助码'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
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
                      icon: const Icon(Icons.paste, size: 16),
                      label: const Text('从剪贴板粘贴'),
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
                    validator: (v) => _mode == _ImportMode.plain &&
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('导入'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Export assist token. Same keyboard rules as import (R-19).
Future<void> showAssistExportDialog(
  BuildContext context, {
  required Future<String> Function({
    required AssistExportKind kind,
    String? username,
    String? password,
  }) export,
  String? suggestedUsername,
  String? savedPassword,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => _AssistExportDialog(
      export: export,
      suggestedUsername: suggestedUsername,
      savedPassword: savedPassword,
    ),
  );
}

class _AssistExportDialog extends StatefulWidget {
  const _AssistExportDialog({
    required this.export,
    this.suggestedUsername,
    this.savedPassword,
  });

  final Future<String> Function({
    required AssistExportKind kind,
    String? username,
    String? password,
  }) export;
  final String? suggestedUsername;
  final String? savedPassword;

  @override
  State<_AssistExportDialog> createState() => _AssistExportDialogState();
}

class _AssistExportDialogState extends State<_AssistExportDialog> {
  late final TextEditingController _userCtrl;
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _kind = AssistExportKind.session;
  var _submitting = false;

  bool get _hasSavedPassword =>
      widget.savedPassword != null && widget.savedPassword!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.suggestedUsername ?? '');
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final sealed = await widget.export(
        kind: _kind,
        username: _kind == AssistExportKind.account
            ? _userCtrl.text.trim()
            : null,
        password: _kind == AssistExportKind.account
            ? (_hasSavedPassword ? widget.savedPassword : _passCtrl.text)
            : null,
      );
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          // Do not pad with viewInsets — dialog route already clears the IME (R-19).
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '导出协助码',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<AssistExportKind>(
                  segments: const [
                    ButtonSegment(
                      value: AssistExportKind.session,
                      label: Text('临时会话'),
                      icon: Icon(Icons.cookie_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: AssistExportKind.account,
                      label: Text('账号密码'),
                      icon: Icon(Icons.key_outlined, size: 16),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: _submitting
                      ? null
                      : (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 12),
                Text(
                  _kind == AssistExportKind.session
                      ? '把当前登录状态做成协助码发给同学。过期后需重新导出，或改用「账号密码」。'
                      : _hasSavedPassword
                          ? '将使用本机保存的学号与密码生成协助码。退出登录后会清除保存的密码。'
                          : '把学号和密码做成协助码发给同学，对方可长期代为登录；你改密码后即失效。',
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                ),
                if (_kind == AssistExportKind.account) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _userCtrl,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '学号'),
                    validator: (v) => _kind == AssistExportKind.account &&
                            (v == null || v.trim().isEmpty)
                        ? '请输入学号'
                        : null,
                  ),
                  if (!_hasSavedPassword) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passCtrl,
                      enabled: !_submitting,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: '密码',
                        hintText: '本次登录未保存密码时需填写',
                      ),
                      validator: (v) => _kind == AssistExportKind.account &&
                              (v == null || v.isEmpty)
                          ? '请输入密码'
                          : null,
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('导出并复制'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showAssistRiskDialog(BuildContext context) async {
  return showAppConfirmDialog(
    context,
    title: '启用协助签到？',
    message:
        '开启后可以：导入同学的协助码或学号密码；从名单进入其签到页代为签到；在二维码签到时一次提交多人。\n\n'
        '「临时会话」会在对方重新登录后失效；「账号密码」相当于分享密码，对方改密后才会失效。\n\n'
        '请仅在双方知情同意下使用，并遵守校规。',
    confirmLabel: '我了解，启用',
  );
}

class AssistIdentitiesPage extends ConsumerWidget {
  const AssistIdentitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assist = ref.watch(assistControllerProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '协助身份',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.pageXOf(context),
          AppSpace.md,
          AppSpace.pageXOf(context),
          AppSpace.xl,
        ),
        children: [
          if (!assist.enabled)
            Text(
              '协助功能已关闭。可在「我的」中开启后再管理名单。',
              style: TextStyle(color: p.muted, height: 1.4),
            )
          else if (assist.identities.isEmpty)
            Text(
              '还没有协助对象。请先导入协助身份，再点姓名进入其签到页。',
              style: TextStyle(color: p.muted, height: 1.4),
            )
          else
            SettingsSection(
              header: '已导入',
              children: [
                for (final id in assist.identities)
                  SettingsRow(
                    leading: Icon(
                      id.kind == AssistCredentialKind.account
                          ? Icons.key_outlined
                          : Icons.cookie_outlined,
                    ),
                    title: id.displayName,
                    subtitle: '${id.kind.labelZh} · 点击进入签到',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AssistRollcallHubPage(identity: id),
                        ),
                      );
                    },
                    trailing: IconButton(
                      tooltip: '删除',
                      onPressed: assist.busy
                          ? null
                          : () async {
                              final ok = await showAppConfirmDialog(
                                context,
                                title: '移除协助账号',
                                message:
                                    '移除「${id.displayName}」并清除其本地登录信息'
                                    '${id.kind == AssistCredentialKind.account ? '与保存的密码' : ''}？',
                                confirmLabel: '移除',
                                destructive: true,
                              );
                              if (!ok) return;
                              await ref
                                  .read(assistControllerProvider.notifier)
                                  .removeIdentity(id.userId);
                            },
                      icon: Icon(Icons.delete_outline, color: p.muted),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
