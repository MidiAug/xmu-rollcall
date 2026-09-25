import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';
import 'package:xmu_rollcall/features/rollcall/qr_scan_camera_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_selection_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

/// QR secondary page: select targets → scan once → serial submit.
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

class _EligibleRow {
  const _EligibleRow({
    required this.identity,
    required this.eligibility,
  });

  final AssistIdentity identity;
  final AssistQrEligibility eligibility;

  bool get canSelect => eligibility == AssistQrEligibility.unsigned;
}

class _QrAnswerPageState extends ConsumerState<QrAnswerPage> {
  final _dataCtrl = TextEditingController();
  bool _includeOwner = true;
  final Set<int> _selectedAssist = {};
  List<_EligibleRow> _rows = const [];
  bool _loadingEligible = false;
  bool _submitting = false;
  List<AssistQrSubmitResult> _results = const [];
  String? _status;
  QrSelectionStore? _selStore;

  bool get _singleAssist =>
      widget.assistUserId != null || !widget.enableAssistMulti;

  bool get _cameraSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

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
      _prepareEligible();
    });
  }

  @override
  void dispose() {
    _dataCtrl.dispose();
    super.dispose();
  }

  Future<QrSelectionStore> _store() async {
    final existing = _selStore;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    return _selStore = QrSelectionStore(prefs);
  }

  Future<void> _prepareEligible() async {
    final assist = ref.read(assistControllerProvider);
    if (assist.identities.isEmpty) {
      setState(() {
        _rows = const [];
        _status = null;
        _includeOwner = true;
        _selectedAssist.clear();
      });
      return;
    }
    final courseId = widget.item.courseId;
    if (courseId == null) {
      setState(() {
        _rows = const [];
        _status = '无法确认同课协助对象，将只提交本人';
        _includeOwner = true;
        _selectedAssist.clear();
      });
      return;
    }

    setState(() {
      _loadingEligible = true;
      _status = '正在核对同课未签对象…';
    });

    try {
      final sameCourse = filterAssistBySharedCache(
        courseId: courseId,
        identities: assist.identities,
      );

      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final assistSvc = await ref.read(assistServiceProvider.future);
      final rows = <_EligibleRow>[];

      for (final a in sameCourse) {
        AssistQrEligibility elig = AssistQrEligibility.unknown;
        try {
          await assistSvc.ensureSession(a);
          final client = registry.forKey(SessionKey.assist(a.userId));
          await client.init();
          final repo = RollcallRepository(http: client, identity: identity);
          final active = await repo.fetchActive();
          elig = eligibilityFromActiveList(
            rollcallId: widget.item.rollcallId,
            active: active,
          );
        } catch (_) {
          elig = AssistQrEligibility.unknown;
        }
        rows.add(_EligibleRow(identity: a, eligibility: elig));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      final store = await _store();
      final saved = await store.read(courseId);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selectedAssist.clear();
        if (saved != null) {
          _includeOwner = saved.includeOwner;
          for (final id in saved.assistUserIds) {
            final row = rows.where((r) => r.identity.userId == id);
            if (row.isNotEmpty && row.first.canSelect) {
              _selectedAssist.add(id);
            }
          }
        } else {
          _includeOwner = true;
        }
        final unsigned = rows.where((r) => r.canSelect).length;
        _status = sameCourse.isEmpty
            ? '无同课协助身份（导入时会缓存同课）'
            : '同课 ${sameCourse.length} 人，其中未签 $unsigned 人可勾选'
                '${saved != null ? '；已恢复本课上次勾选' : '；默认仅本人'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _status = '核对协助对象失败：$e';
      });
    } finally {
      if (mounted) setState(() => _loadingEligible = false);
    }
  }

  Future<void> _persistSelection() async {
    final courseId = widget.item.courseId;
    if (courseId == null || _singleAssist) return;
    final store = await _store();
    await store.write(
      courseId,
      QrSelectionSnapshot(
        includeOwner: _includeOwner,
        assistUserIds: Set<int>.from(_selectedAssist),
      ),
    );
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() => _dataCtrl.text = text);
  }

  List<AssistQrTarget> _buildTargets() {
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
      return targets;
    }

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
    for (final row in _rows) {
      if (!_selectedAssist.contains(row.identity.userId)) continue;
      if (!row.canSelect) continue;
      final a = row.identity;
      targets.add(
        AssistQrTarget(
          key: SessionKey.assist(a.userId),
          label: a.displayName,
          userId: a.userId,
          deviceId: a.deviceId,
        ),
      );
    }
    return targets;
  }

  Future<void> _scanAndSubmit() async {
    if (_cameraSupported) {
      final raw = await Navigator.of(context).push<String>(
        AppPageRoutes.build(const QrScanCameraPage()),
      );
      if (raw == null || raw.isEmpty) return;
      setState(() => _dataCtrl.text = raw);
      await _submitWithData(raw);
      return;
    }

    // Desktop / unsupported: require pasted content then submit.
    if (_dataCtrl.text.trim().isEmpty) {
      await _pasteClipboard();
    }
    if (_dataCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴二维码内容，再点扫码提交')),
      );
      return;
    }
    await _submitWithData(_dataCtrl.text);
  }

  Future<void> _submit() => _submitWithData(_dataCtrl.text);

  Future<void> _submitWithData(String rawInput) async {
    late final String qrData;
    try {
      qrData = parseQrRollcallData(rawInput);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }

    final targets = _buildTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一个提交对象')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _results = const [];
    });
    await _persistSelection();

    final batchOpId = RollcallLog.newOpId();
    final hashPrefix =
        sha256.convert(utf8.encode(qrData)).toString().substring(0, 8);
    RollcallLog.qrPayloadHashed(
      opId: batchOpId,
      payloadLen: qrData.length,
      payloadSha256Prefix: hashPrefix,
    );
    RollcallLog.qrBatch(
      batchOpId: batchOpId,
      targetCount: targets.length,
    );

    final registry = ref.read(sessionClientRegistryProvider);
    final identity = ref.read(deviceIdentityProvider);
    final assistSvc = await ref.read(assistServiceProvider.future);
    final runner = AssistQrBatchRunner(
      submit: (target, data) async {
        final opId = RollcallLog.newOpId();
        final started = DateTime.now();
        final session = target.key.isOwner ? 'owner' : 'assist';
        final assistUid = target.key.isOwner ? null : target.userId;
        bool? ok;
        try {
          RollcallLog.start(
            opId: opId,
            type: 'qr',
            rollcallId: widget.item.rollcallId,
            courseTitle: widget.item.courseTitle,
            session: session,
            assistUserId: assistUid,
            batchOpId: batchOpId,
          );
          if (target.key.isAssist) {
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
              } catch (_) {}
            }
          }
          final client = registry.forKey(target.key);
          await client.init();
          final repo = RollcallRepository(http: client, identity: identity);
          final result = await repo.answerQr(
            rollcallId: widget.item.rollcallId,
            data: data,
            deviceId: target.deviceId,
            opId: opId,
          );
          ok = result.ok;
          return result;
        } catch (e, st) {
          RollcallLog.exception(
            opId: opId,
            rollcallId: widget.item.rollcallId,
            error: e,
            stackTrace: st,
          );
          rethrow;
        } finally {
          RollcallLog.end(
            opId: opId,
            rollcallId: widget.item.rollcallId,
            durationMs: DateTime.now().difference(started).inMilliseconds,
            ok: ok,
          );
        }
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
      // Refresh eligibility so signed rows grey out.
      if (!_singleAssist) {
        await _prepareEligible();
      }
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
    final opId = RollcallLog.newOpId();
    final started = DateTime.now();
    bool? ok;
    try {
      final data = parseQrRollcallData(_dataCtrl.text);
      final hashPrefix =
          sha256.convert(utf8.encode(data)).toString().substring(0, 8);
      RollcallLog.qrPayloadHashed(
        opId: opId,
        payloadLen: data.length,
        payloadSha256Prefix: hashPrefix,
      );
      RollcallLog.start(
        opId: opId,
        type: 'qr',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: failed.target.key.isOwner ? 'owner' : 'assist',
        assistUserId:
            failed.target.key.isOwner ? null : failed.target.userId,
      );
      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final client = registry.forKey(failed.target.key);
      await client.init();
      final repo = RollcallRepository(http: client, identity: identity);
      final again = await repo.answerQr(
        rollcallId: widget.item.rollcallId,
        data: data,
        deviceId: failed.target.deviceId,
        opId: opId,
      );
      ok = again.ok;
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
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      RollcallLog.end(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        ok: ok,
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _eligLabel(AssistQrEligibility e) => switch (e) {
        AssistQrEligibility.unsigned => '未签',
        AssistQrEligibility.signedOrDone => '已签/无需',
        AssistQrEligibility.unknown => '状态未知',
      };

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
                padTop: false,
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
                  for (final row in _rows)
                    SettingsRow(
                      leading: Icon(
                        Icons.handshake_outlined,
                        color: row.canSelect ? null : p.muted,
                      ),
                      title: row.identity.displayName,
                      subtitle: _eligLabel(row.eligibility),
                      onTap: (_submitting || !row.canSelect)
                          ? null
                          : () {
                              setState(() {
                                final id = row.identity.userId;
                                if (_selectedAssist.contains(id)) {
                                  _selectedAssist.remove(id);
                                } else {
                                  _selectedAssist.add(id);
                                }
                              });
                            },
                      trailing: IgnorePointer(
                        child: Checkbox(
                          value: _selectedAssist.contains(row.identity.userId),
                          onChanged: row.canSelect ? (_) {} : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            if (!_cameraSupported) ...[
              TextField(
                controller: _dataCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '二维码内容',
                  hintText: '桌面端请粘贴扫码得到的内容',
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
            ],
            FilledButton.icon(
              onPressed: _submitting ? null : _scanAndSubmit,
              icon: Icon(
                _cameraSupported ? Icons.qr_code_scanner : Icons.done_all,
                size: 18,
              ),
              label: Text(
                _submitting
                    ? '提交中…'
                    : (_cameraSupported ? '扫码' : '确认并提交'),
              ),
            ),
            if (_cameraSupported) ...[
              const SizedBox(height: AppSpace.xs),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        await _pasteClipboard();
                        if (_dataCtrl.text.trim().isNotEmpty) {
                          await _submit();
                        }
                      },
                child: const Text('粘贴内容并提交'),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              SettingsSection(
                padTop: false,
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
