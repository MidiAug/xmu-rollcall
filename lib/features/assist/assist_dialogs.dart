import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_identity_card.dart';

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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
                    : '将使用本机保存的学号与密码生成协助码，对方可长期代为登录；你改密码或退出登录后需重新导出。',
                style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
              ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}

class AssistIdentitiesPage extends ConsumerWidget {
  const AssistIdentitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assist = ref.watch(assistControllerProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '协助身份',
      body: AppContentColumn(
        child: assist.identities.isEmpty
            ? EmptyHint(
                icon: Icons.person_add_alt_1_outlined,
                title: '还没有协助对象',
                detail: '请先导入协助身份，再点姓名进入其签到页。',
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  AppSpace.sm,
                  AppSpace.pageXOf(context),
                  AppSpace.xl,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xs,
                      0,
                      AppSpace.xs,
                      AppSpace.xs,
                    ),
                    child: Text(
                      '已导入 ${assist.identities.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.muted,
                      ),
                    ),
                  ),
                  for (final id in assist.identities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: AssistIdentityCard(identity: id),
                    ),
                ],
              ),
      ),
    );
  }
}
