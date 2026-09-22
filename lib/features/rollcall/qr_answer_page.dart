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
  const QrAnswerPage({
    super.key,
    required this.item,
    this.assistUserId,
    this.enableAssistMulti = true,
  });

  final RollcallItem item;

  /// When set, this page operates for that assist identity only.
  final int? assistUserId;

  /// Owner QR multi-assist UI; false on assist hub (no「再协助他人」).
  final bool enableAssistMulti;

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

  bool get _singleAssist =>
      widget.assistUserId != null || !widget.enableAssistMulti;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_singleAssist) {
        setState(() {
          _status = widget.assistUserId != null
              ? '将以该协助身份提交（不勾选他人）'
              : null;
        });
        return;
      }
      _loadEligible();
    });
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
        _status = assist.enabled ? null : '协助未开启，将只提交本人';
      });
      return;
    }
    final courseId = widget.item.courseId;
    if (courseId == null) {
      setState(() {
        _eligible = const [];
        _status = '无法确认同课协助对象，将只提交本人';
      });
      return;
    }

    setState(() {
      _loadingEligible = true;
      _status = '正在核对协助对象的课程…';
    });

    try {
      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final assistSvc = await ref.read(assistServiceProvider.future);
      final byUser = <int, Set<String>>{};
      for (final a in assist.identities) {
        try {
          await assistSvc.ensureSession(a);
        } catch (_) {
          byUser[a.userId] = {};
          continue;
        }
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
    if (_singleAssist) {
      final assistId = widget.assistUserId;
      if (assistId != null) {
        final roster = ref.read(assistControllerProvider).identities;
        AssistIdentity? meta;
        for (final e in roster) {
          if (e.userId == assistId) {
            meta = e;
            break;
          }
        }
        targets.add(
          AssistQrTarget(
            key: SessionKey.assist(assistId),
            label: meta?.displayName ?? '协助',
            userId: assistId,
            deviceId: meta?.deviceId,
          ),
        );
      } else {
        final profile = ref.read(authControllerProvider).profile;
        targets.add(
          AssistQrTarget(
            key: SessionKey.owner,
            label: profile?.name ?? '我',
            userId: profile?.id ?? 0,
          ),
        );
      }
    } else {
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
              deviceId: a.deviceId,
            ),
          );
        }
      }
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一人')),
      );
      return;
    }

    final names = targets.map((t) => t.label).join('、');
    final ok = await showAppConfirmDialog(
      context,
      title: '确认二维码签到',
      message: '课程：${widget.item.courseTitle}\n'
          '对象（${targets.length}）：$names\n\n'
          '将按顺序为所选对象提交同一份二维码。',
      confirmLabel: '确认提交',
    );
    if (!ok) return;

    setState(() {
      _submitting = true;
      _results = const [];
    });

    final registry = ref.read(sessionClientRegistryProvider);
    final identity = ref.read(deviceIdentityProvider);
    final assistSvc = await ref.read(assistServiceProvider.future);
    final runner = AssistQrBatchRunner(
      submit: (target, data) async {
        if (!target.key.isOwner) {
          final roster = ref.read(assistControllerProvider).identities;
          AssistIdentity? meta;
          for (final e in roster) {
            if (e.userId == target.userId) {
              meta = e;
              break;
            }
          }
          if (meta != null) {
            try {
              await assistSvc.ensureSession(meta);
            } catch (_) {
              // Fall through; answer will surface the error.
            }
          }
        }
        final client = registry.forKey(target.key);
        await client.init();
        final repo = RollcallRepository(http: client, identity: identity);
        return repo.answerQr(
          rollcallId: widget.item.rollcallId,
          data: data,
          deviceId: target.deviceId,
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
        deviceId: failed.target.deviceId,
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
      body: AppContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppSpace.md,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
            Text(
              item.courseTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
                color: p.ink,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '发起人：${item.createdByName}',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            if (_status != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                _status!,
                style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            if (!_singleAssist) ...[
              SettingsSection(
                header: '提交对象',
                children: [
                  SettingsRow(
                    leading: const Icon(Icons.person_outline),
                    title: '我',
                    onTap: _submitting
                        ? null
                        : () => setState(() => _includeOwner = !_includeOwner),
                    trailing: IgnorePointer(
                      child: Checkbox(
                        value: _includeOwner,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                  if (_loadingEligible)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  for (final a in _eligible)
                    SettingsRow(
                      leading: const Icon(Icons.handshake_outlined),
                      title: a.displayName,
                      onTap: _submitting
                          ? null
                          : () {
                              setState(() {
                                if (_selectedAssist.contains(a.userId)) {
                                  _selectedAssist.remove(a.userId);
                                } else {
                                  _selectedAssist.add(a.userId);
                                }
                              });
                            },
                      trailing: IgnorePointer(
                        child: Checkbox(
                          value: _selectedAssist.contains(a.userId),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            TextField(
              controller: _dataCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '二维码内容',
                hintText: '粘贴扫码得到的内容',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : _pasteClipboard,
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('从剪贴板粘贴'),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '提交中…' : '确认并提交'),
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              SettingsSection(
                header: '结果',
                children: [
                  for (final r in _results)
                    SettingsRow(
                      leading: Icon(
                        r.ok
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
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
    );
  }
}
