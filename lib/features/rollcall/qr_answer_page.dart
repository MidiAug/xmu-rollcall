import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

/// QR secondary page: paste/scan data once → serial submit for selected identities.
class QrAnswerPage extends ConsumerStatefulWidget {
  const QrAnswerPage({super.key, required this.item});

  final RollcallItem item;

  @override
  ConsumerState<QrAnswerPage> createState() => _QrAnswerPageState();
}

class _QrAnswerPageState extends ConsumerState<QrAnswerPage> {
  final _dataCtrl = TextEditingController();
  bool _includeOwner = true;
  final Set<int> _selectedAssist = {};
  List<AssistIdentity> _eligible = const [];
  bool _loadingEligible = false;
  bool _submitting = false;
  List<AssistQrSubmitResult> _results = const [];
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEligible());
  }

  @override
  void dispose() {
    _dataCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEligible() async {
    final assist = ref.read(assistControllerProvider);
    if (!assist.enabled || assist.identities.isEmpty) {
      setState(() {
        _eligible = const [];
        _status = assist.enabled ? null : '协助未开启：仅提交主号';
      });
      return;
    }
    final courseId = widget.item.courseId;
    if (courseId == null) {
      setState(() {
        _eligible = const [];
        _status = '列表未带 course_id，无法过滤同课协助（仅主号）';
      });
      return;
    }

    setState(() {
      _loadingEligible = true;
      _status = '正在核对协助身份课程…';
    });

    try {
      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final byUser = <int, Set<String>>{};
      for (final a in assist.identities) {
        final client = registry.forKey(SessionKey.assist(a.userId));
        await client.init();
        final repo = RollcallRepository(http: client, identity: identity);
        try {
          byUser[a.userId] = await repo.fetchCourseIds();
        } catch (_) {
          byUser[a.userId] = {};
        }
      }
      final eligible = filterAssistForCourse(
        courseId: courseId,
        identities: assist.identities,
        courseIdsByUser: byUser,
      );
      if (!mounted) return;
      setState(() {
        _eligible = eligible;
        _selectedAssist.clear();
        _status = eligible.isEmpty
            ? '无同课协助身份可勾选'
            : '本课可协助 ${eligible.length} 人（默认不勾选，按需勾选）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eligible = const [];
        _status = '核对协助课程失败：$e';
      });
    } finally {
      if (mounted) setState(() => _loadingEligible = false);
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() => _dataCtrl.text = text);
  }

  Future<void> _submit() async {
    late final String qrData;
    try {
      qrData = parseQrRollcallData(_dataCtrl.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }

    final targets = <AssistQrTarget>[];
    if (_includeOwner) {
      final profile = ref.read(authControllerProvider).profile;
      targets.add(
        AssistQrTarget(
          key: SessionKey.owner,
          label: profile?.name ?? '我',
          userId: profile?.id ?? 0,
        ),
      );
    }
    for (final a in _eligible) {
      if (_selectedAssist.contains(a.userId)) {
        targets.add(
          AssistQrTarget(
            key: SessionKey.assist(a.userId),
            label: a.displayName,
            userId: a.userId,
          ),
        );
      }
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一个提交对象')),
      );
      return;
    }

    final names = targets.map((t) => t.label).join('、');
    final ok = await showAppConfirmDialog(
      context,
      title: '确认二维码签到',
      message: '课程：${widget.item.courseTitle}\n'
          '对象（${targets.length}）：$names\n\n'
          '将串行提交同一份二维码 data（非并发）。',
      confirmLabel: '确认提交',
    );
    if (!ok) return;

    setState(() {
      _submitting = true;
      _results = const [];
    });

    final registry = ref.read(sessionClientRegistryProvider);
    final identity = ref.read(deviceIdentityProvider);
    final runner = AssistQrBatchRunner(
      submit: (target, data) async {
        final client = registry.forKey(target.key);
        await client.init();
        final repo = RollcallRepository(http: client, identity: identity);
        return repo.answerQr(
          rollcallId: widget.item.rollcallId,
          data: data,
        );
      },
    );

    try {
      final results = await runner.run(qrData: qrData, targets: targets);
      for (final r in results) {
        await ref.read(historyProvider.notifier).add(
              RollcallHistoryEntry(
                rollcallId: widget.item.rollcallId,
                courseTitle: widget.item.courseTitle,
                typeLabel: '二维码·${r.target.label}',
                ok: r.ok,
                at: DateTime.now(),
                detail: r.message,
              ),
            );
      }
      if (!mounted) return;
      setState(() => _results = results);
      final okCount = results.where((e) => e.ok).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('完成：$okCount/${results.length} 成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交异常：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _retryTarget(AssistQrSubmitResult failed) async {
    setState(() => _submitting = true);
    try {
      final data = parseQrRollcallData(_dataCtrl.text);
      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final client = registry.forKey(failed.target.key);
      await client.init();
      final repo = RollcallRepository(http: client, identity: identity);
      final again = await repo.answerQr(
        rollcallId: widget.item.rollcallId,
        data: data,
      );
      if (!mounted) return;
      setState(() {
        _results = [
          for (final x in _results)
            if (x.target.userId == failed.target.userId &&
                x.target.key == failed.target.key)
              AssistQrSubmitResult(
                target: failed.target,
                ok: again.ok,
                message: again.message,
              )
            else
              x,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '二维码签到',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                item.courseTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '发起人：${item.createdByName}'
                '${item.courseId != null ? " · 课 ${item.courseId}" : ""}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                '提交对象',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _includeOwner,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _includeOwner = v ?? true),
                title: const Text('我（主号）'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_loadingEligible)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              for (final a in _eligible)
                CheckboxListTile(
                  value: _selectedAssist.contains(a.userId),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selectedAssist.add(a.userId);
                            } else {
                              _selectedAssist.remove(a.userId);
                            }
                          });
                        },
                  title: Text(a.displayName),
                  subtitle: Text('ID ${a.userId}'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _dataCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '二维码内容 / data',
                  hintText: '粘贴扫码结果或剪贴板（相机扫码后续接入）',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _submitting ? null : _pasteClipboard,
                  icon: const Icon(Icons.paste, size: 16),
                  label: const Text('从剪贴板粘贴'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '串行提交中…' : '确认并提交'),
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '结果',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 8),
                SettingsSection(
                  children: [
                    for (final r in _results)
                      SettingsRow(
                        leading: Icon(
                          r.ok ? Icons.check_circle_outline : Icons.error_outline,
                          color: r.ok ? p.primary : p.danger,
                        ),
                        title: r.target.label,
                        subtitle: r.message ?? (r.ok ? '成功' : '失败'),
                        trailing: r.ok
                            ? null
                            : TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _retryTarget(r),
                                child: const Text('重试'),
                              ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
