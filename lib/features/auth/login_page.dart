import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';

Future<void> showLoginDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: LoginDialog(),
    ),
  );
}

class LoginDialog extends ConsumerStatefulWidget {
  const LoginDialog({super.key});

  @override
  ConsumerState<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<LoginDialog> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final last = await ref.read(authRepositoryProvider).lastUsername();
    if (last != null && last.isNotEmpty && mounted) {
      _userCtrl.text = last;
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            username: _userCtrl.text.trim(),
            password: _passCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final loading = _submitting || auth.status == AuthStatus.loading;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '登录畅课',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 18, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '使用学号与统一身份认证密码',
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _userCtrl,
                enabled: !loading,
                autofocus: true,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                decoration: const InputDecoration(
                  labelText: '学号',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入学号';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                enabled: !loading,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入密码';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: p.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登录'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '密码只用于本次请求，不会保存在本地。',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
