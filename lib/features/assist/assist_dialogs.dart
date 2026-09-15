import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';

Future<void> showAssistImportDialog(
  BuildContext context, {
  required Future<void> Function(String sealed, String passphrase) onSubmit,
}) async {
  final passCtrl = TextEditingController();
  final pkgCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final inset = MediaQuery.viewInsetsOf(ctx);
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('导入协助凭证'),
            content: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: inset.bottom > 0 ? 8 : 0),
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: pkgCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '凭证包',
                          hintText: '粘贴对方导出的 JSON',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请粘贴凭证包' : null,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  final text = data?.text;
                                  if (text != null && text.isNotEmpty) {
                                    pkgCtrl.text = text;
                                  }
                                },
                          icon: const Icon(Icons.paste, size: 16),
                          label: const Text('从剪贴板粘贴'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '口令'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请输入口令' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                        setLocal(() => submitting = true);
                        try {
                          await onSubmit(pkgCtrl.text.trim(), passCtrl.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            AppToast.show(ctx, '$e', error: true);
                          }
                        } finally {
                          if (ctx.mounted) {
                            setLocal(() => submitting = false);
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('导入'),
              ),
            ],
          );
        },
      );
    },
  );

  passCtrl.dispose();
  pkgCtrl.dispose();
}

Future<void> showAssistExportDialog(
  BuildContext context, {
  required Future<String> Function(String passphrase) export,
}) async {
  final passCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final muted = AppPalette.of(ctx).muted;
          final inset = MediaQuery.viewInsetsOf(ctx);
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('导出主号会话凭证'),
            content: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: inset.bottom > 0 ? 8 : 0),
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '导出的是登录态（非 IDS 密码）。对方导入后可使用该会话。建议短时口令；默认约 24 小时过期。',
                        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '口令'),
                        validator: (v) =>
                            (v == null || v.trim().length < 4) ? '至少 4 位' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                        setLocal(() => submitting = true);
                        try {
                          final sealed = await export(passCtrl.text);
                          await Clipboard.setData(ClipboardData(text: sealed));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            AppToast.show(context, '已复制到剪贴板');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            AppToast.show(ctx, '$e', error: true);
                          }
                        } finally {
                          if (ctx.mounted) {
                            setLocal(() => submitting = false);
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('导出并复制'),
              ),
            ],
          );
        },
      );
    },
  );

  passCtrl.dispose();
}

Future<bool> showAssistRiskDialog(BuildContext context) async {
  return showAppConfirmDialog(
    context,
    title: '启用协助能力？',
    message:
        '导入他人会话凭证后，本机可使用对方的畅课登录态提交签到（仅限同课二维码场景）。\n\n'
        '会话≈账号控制权；请仅在知情同意下使用，并遵守校规。对方重新登录可吊销旧会话。\n\n'
        '默认关闭；开启后请自行管理导入名单。',
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
              '协助总开关已关闭。可在「我的」中开启后再管理名单。',
              style: TextStyle(color: p.muted, height: 1.4),
            )
          else if (assist.identities.isEmpty)
            Text(
              '尚未导入协助身份。请使用「导入会话凭证」。',
              style: TextStyle(color: p.muted, height: 1.4),
            )
          else
            SettingsSection(
              header: '已导入',
              children: [
                for (final id in assist.identities)
                  SettingsRow(
                    leading: const Icon(Icons.person_outline),
                    title: id.displayName,
                    subtitle: 'ID ${id.userId}',
                    trailing: IconButton(
                      tooltip: '删除',
                      onPressed: assist.busy
                          ? null
                          : () async {
                              final ok = await showAppConfirmDialog(
                                context,
                                title: '移除协助账号',
                                message:
                                    '移除「${id.displayName}」并清除其会话 Cookie？',
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
