import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_store.dart';
import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/rollcall/qr_scan_camera_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_selection_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/platform/desktop_qr_scanner.dart';

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
    this.directSession = false,
  });

  final bool directSession;
  SessionKey get key =>
      directSession ? SessionKey.owner : SessionKey.assist(identity.userId);

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
  bool _scanning = false;
  bool _primaryDone = false;
  final Set<int> _completedAssist = {};
  int? _ownerUserId;
  int? _selectedScopeAtOpen;
  List<AssistQrSubmitResult> _results = const [];
  String? _status;
  QrSelectionStore? _selStore;
  String? get _selectionCourseId {
    final courseId = widget.item.courseId;
    if (courseId == null) return null;
    return widget.assistUserId == null
        ? courseId
        : '${courseId}_primary_${widget.assistUserId}';
  }

  bool get _singleAssist => !widget.enableAssistMulti;

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

  bool get _desktopSupported => DesktopQrScanner.supported;

  @override
  void initState() {
    super.initState();
    _ownerUserId = ref.read(authControllerProvider).profile?.id;
    _selectedScopeAtOpen = ref.read(selectedRollcallAccountProvider);
    _primaryDone = widget.item.isAnswered || widget.item.isExpired;
    _includeOwner = !_primaryDone;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_singleAssist) {
        setState(() {
          _status = widget.assistUserId != null ? '仅为当前账号提交' : null;
        });
        return;
      }
      _prepareEligible();
    });
  }

  @override
  void dispose() {
    if (_scanning && _desktopSupported) unawaited(DesktopQrScanner.cancel());
    _dataCtrl.dispose();
    super.dispose();
  }

  Future<QrSelectionStore> _store() async {
    final uid = ref.read(authControllerProvider).profile?.id ?? 0;
    final existing = _selStore;
    if (existing != null && existing.userId == uid) return existing;
    final prefs = await SharedPreferences.getInstance();
    return _selStore = QrSelectionStore(prefs, userId: uid);
  }

  Future<void> _prepareEligible() async {
    final assist = ref.read(assistControllerProvider);
    if (assist.identities.isEmpty && widget.assistUserId == null) {
      setState(() {
        _rows = const [];
        _status = null;
        _includeOwner = !_primaryDone;
        _selectedAssist.clear();
      });
      return;
    }
    final courseId = widget.item.courseId;

    setState(() {
      _loadingEligible = true;
      _status = '正在查看可协助的同学…';
    });

    try {
      // Import-time intersections can be stale. The same active event proves
      // same-course eligibility even if its course id is absent from the list.
      final candidates = assist.identities
          .where((a) => a.userId != widget.assistUserId)
          .toList();

      final profile = ref.read(authControllerProvider).profile;
      if (widget.assistUserId != null &&
          profile != null &&
          !candidates.any((a) => a.userId == profile.id)) {
        candidates.add(
          AssistIdentity(
            userId: profile.id,
            displayName: profile.name,
            kind: AssistCredentialKind.session,
          ),
        );
      }
      final registry = ref.read(sessionClientRegistryProvider);
      final identity = ref.read(deviceIdentityProvider);
      final assistSvc = await ref.read(assistServiceProvider.future);
      final rows = <_EligibleRow>[];

      for (final a in candidates) {
        _checkSession();
        final directSession =
            widget.assistUserId != null && a.userId == _ownerUserId;
        AssistQrEligibility elig = AssistQrEligibility.unknown;
        try {
          if (!directSession) await assistSvc.ensureSession(a);
          final client = registry.forKey(
            directSession ? SessionKey.owner : SessionKey.assist(a.userId),
          );
          await client.init();
          final repo = RollcallRepository(
            http: client,
            identity: identity,
            loadDetectionWindow: DetectionWindowStore.read,
          );
          final active = await repo.fetchActive();
          _checkSession();
          if (!active.any(
                (item) => item.rollcallId == widget.item.rollcallId,
              ) &&
              !a.sharesCourse(courseId)) {
            continue;
          }
          elig = eligibilityFromActiveList(
            rollcallId: widget.item.rollcallId,
            active: active,
          );
        } catch (error) {
          AppLog.event(
            'qr.eligibility.error',
            level: 'W',
            fields: {
              'rollcallId': widget.item.rollcallId,
              'assistUserId': a.userId,
              'errorType': error.runtimeType.toString(),
            },
          );
          if (!a.sharesCourse(courseId)) continue;
          elig = AssistQrEligibility.unknown;
        }
        if (_completedAssist.contains(a.userId)) {
          elig = AssistQrEligibility.signedOrDone;
        }
        AppLog.event(
          'qr.eligibility.result',
          fields: {
            'rollcallId': widget.item.rollcallId,
            'assistUserId': a.userId,
            'eligibility': elig.name,
          },
        );
        rows.add(
          _EligibleRow(
            identity: a,
            eligibility: elig,
            directSession: directSession,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      _checkSession();
      QrSelectionSnapshot? saved;
      try {
        final store = await _store();
        final key = _selectionCourseId;
        saved = key == null ? null : await store.read(key);
      } catch (error) {
        AppLog.event(
          'qr.selection.restore_failed',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selectedAssist.clear();
        if (saved != null) {
          _includeOwner = saved.includeOwner && !_primaryDone;
          for (final id in saved.assistUserIds) {
            final row = rows.where((r) => r.identity.userId == id);
            if (row.isNotEmpty && row.first.canSelect) {
              _selectedAssist.add(id);
            }
          }
        } else {
          _includeOwner = !_primaryDone;
        }
        final unsigned = rows.where((r) => r.canSelect).length;
        _status = rows.isEmpty
            ? '没有其他同学需要协助'
            : '可协助 $unsigned 位同学'
                  '${saved != null ? '，已恢复上次选择' : '，默认仅自己'}';
      });
    } catch (e) {
      AppLog.event(
        'qr.eligibility.error',
        level: 'W',
        fields: {
          'rollcallId': widget.item.rollcallId,
          'errorType': e.runtimeType.toString(),
        },
      );
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _status = '暂时无法查看其他同学，请重试';
      });
    } finally {
      if (mounted) setState(() => _loadingEligible = false);
    }
  }

  Future<void> _persistSelection() async {
    final courseId = _selectionCourseId;
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
    if (mounted) setState(() => _dataCtrl.text = text);
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
            label: meta?.displayName ?? '账号',
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
      final primaryId = widget.assistUserId;
      final primary = ref
          .read(assistControllerProvider)
          .identities
          .where((a) => a.userId == primaryId)
          .firstOrNull;
      targets.add(
        AssistQrTarget(
          key: primaryId == null
              ? SessionKey.owner
              : SessionKey.assist(primaryId),
          label: primary?.displayName ?? profile?.name ?? '我',
          userId: primaryId ?? profile?.id ?? 0,
          deviceId: primary?.deviceId,
        ),
      );
    }
    for (final row in _rows) {
      if (!_selectedAssist.contains(row.identity.userId)) continue;
      if (!row.canSelect) continue;
      final a = row.identity;
      targets.add(
        AssistQrTarget(
          key: row.key,
          label: a.displayName,
          userId: a.userId,
          deviceId: a.deviceId,
        ),
      );
    }
    return targets;
  }

  Future<void> _scanAndSubmit() async {
    if (_submitting || _scanning || _loadingEligible || widget.item.isExpired) {
      return;
    }
    if (_buildTargets().isEmpty) {
      AppToast.show(context, '请先勾选要签到的人');
      return;
    }
    if (_cameraSupported || _desktopSupported) {
      setState(() => _scanning = true);
      String? raw;
      try {
        raw = _desktopSupported
            ? await DesktopQrScanner.open(
                rollcallId: widget.item.rollcallId,
                courseId: widget.item.courseId,
              )
            : await Navigator.of(context).push<String>(
                AppPageRoutes.build(
                  QrScanCameraPage(
                    rollcallId: widget.item.rollcallId,
                    courseId: widget.item.courseId,
                  ),
                ),
              );
      } catch (error) {
        AppLog.event(
          'qr.scan.open_error',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
        if (mounted) {
          AppToast.show(context, '扫码暂不可用，请重试或粘贴二维码内容提交');
        }
        return;
      } finally {
        if (mounted) setState(() => _scanning = false);
      }
      if (!mounted) return;
      final scanned = raw;
      if (scanned == null || scanned.isEmpty) return;
      setState(() => _dataCtrl.text = scanned);
      await _submitWithData(scanned);
      return;
    }

    // Desktop / unsupported: require pasted content then submit.
    if (_dataCtrl.text.trim().isEmpty) {
      await _pasteClipboard();
    }
    if (_dataCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      AppToast.show(context, '请先粘贴二维码内容，再点扫码提交');
      return;
    }
    await _submitWithData(_dataCtrl.text);
  }

  Future<void> _submit() => _submitWithData(_dataCtrl.text);

  void _checkSession() {
    if (!mounted ||
        ref.read(authControllerProvider).profile?.id != _ownerUserId ||
        ref.read(selectedRollcallAccountProvider) != _selectedScopeAtOpen) {
      throw StateError('登录身份已变化，请返回签到页重试');
    }
  }

  Future<AnswerResult> _submitTarget(
    AssistQrTarget target,
    String data,
    String batchOpId,
  ) async {
    _checkSession();
    final opId = RollcallLog.newOpId();
    final started = DateTime.now();
    bool? ok;
    RollcallLog.start(
      opId: opId,
      type: 'qr',
      rollcallId: widget.item.rollcallId,
      courseTitle: widget.item.courseTitle,
      session: target.key.isOwner ? 'owner' : 'assist',
      assistUserId: target.key.isAssist ? target.userId : null,
      batchOpId: batchOpId,
    );
    try {
      var deviceId = target.deviceId;
      if (target.key.isAssist) {
        final meta = ref
            .read(assistControllerProvider)
            .identities
            .where((a) => a.userId == target.userId)
            .firstOrNull;
        if (meta == null) throw StateError('该身份已从名单移除');
        final service = await ref.read(assistServiceProvider.future);
        await service.ensureSession(meta);
        deviceId = (await service.ensureDeviceId(meta)).deviceId;
      }
      _checkSession();
      final client = ref.read(sessionClientRegistryProvider).forKey(target.key);
      await client.init();
      _checkSession();
      final repo = RollcallRepository(
        loadDetectionWindow: DetectionWindowStore.read,
        http: client,
        identity: ref.read(deviceIdentityProvider),
        deviceIdOverride: deviceId,
        requireExplicitDeviceId: target.key.isAssist,
      );
      // Recheck immediately before submission: the classroom may have ended
      // or this person may have signed since the selection was prepared.
      final active = await repo.fetchActive();
      _checkSession();
      final current = active
          .where((item) => item.rollcallId == widget.item.rollcallId)
          .firstOrNull;
      if (current == null || current.isExpired) {
        return const AnswerResult(ok: false, message: '签到已结束，或该账号无法参与');
      }
      if (current.isAnswered) {
        ok = true;
        AppLog.event(
          'qr.submit.skipped',
          fields: {
            'rollcallId': widget.item.rollcallId,
            'session': target.key.storageId,
            'reason': 'already_answered',
          },
        );
        return const AnswerResult(ok: true, message: '已签到，无需重复提交');
      }
      if (!current.isQrcode) {
        return const AnswerResult(ok: false, message: '签到类型已变化，请刷新后重试');
      }
      final result = await repo.answerQr(
        rollcallId: current.rollcallId,
        data: data,
        opId: opId,
      );
      ok = result.ok;
      return result;
    } catch (error, stack) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: error,
        stackTrace: stack,
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
  }

  Future<void> _submitWithData(String rawInput) async {
    if (_submitting || _loadingEligible || widget.item.isExpired) return;
    late final String qrData;
    try {
      qrData = parseQrRollcallData(
        rawInput,
        expectedRollcallId: widget.item.rollcallId,
        expectedCourseId: widget.item.courseId,
      );
    } catch (_) {
      AppLog.event(
        'qr.payload.invalid',
        level: 'W',
        fields: {
          'rollcallId': widget.item.rollcallId,
          'payloadLen': rawInput.length,
        },
      );
      AppToast.show(context, '二维码内容无效或不属于本次签到，请重新扫描');
      return;
    }
    final targets = _buildTargets();
    if (targets.isEmpty) {
      AppToast.show(context, '请选择要签到的账号');
      return;
    }
    setState(() {
      _submitting = true;
      _results = const [];
    });
    final batchOpId = RollcallLog.newOpId();
    RollcallLog.qrPayloadHashed(
      opId: batchOpId,
      payloadLen: qrData.length,
      payloadSha256Prefix: sha256
          .convert(utf8.encode(qrData))
          .toString()
          .substring(0, 8),
    );
    RollcallLog.qrBatch(batchOpId: batchOpId, targetCount: targets.length);
    try {
      _checkSession();
      try {
        await _persistSelection();
      } catch (error) {
        AppLog.event(
          'qr.selection.save_failed',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
      }
      final runner = AssistQrBatchRunner(
        submit: (target, data) => _submitTarget(target, data, batchOpId),
      );
      final results = await runner.run(qrData: qrData, targets: targets);
      _checkSession();
      setState(() {
        _results = results;
        for (final result in results.where((r) => r.ok)) {
          if (result.target.key.isAssist) {
            _completedAssist.add(result.target.userId);
          }
          if (result.target.key ==
              (widget.assistUserId == null
                  ? SessionKey.owner
                  : SessionKey.assist(widget.assistUserId!))) {
            _primaryDone = true;
            _includeOwner = false;
          }
          _selectedAssist.remove(result.target.userId);
        }
      });
      for (final result in results) {
        await ref
            .read(
              ref
                  .read(
                    localHistoryForProvider(
                      result.target.key.isOwner ? null : result.target.userId,
                    ),
                  )
                  .notifier,
            )
            .add(
              RollcallHistoryEntry(
                rollcallId: widget.item.rollcallId,
                courseTitle: widget.item.courseTitle,
                typeLabel: '二维码（${result.target.label}）',
                ok: result.ok,
                at: DateTime.now(),
                detail: result.message,
              ),
            );
        _checkSession();
        await ref
            .read(
              activeRollcallsProvider(
                result.target.key.isOwner ? null : result.target.userId,
              ).notifier,
            )
            .refresh();
        _checkSession();
      }
      final okCount = results.where((r) => r.ok).length;
      AppLog.event(
        'qr.batch.complete',
        fields: {
          'rollcallId': widget.item.rollcallId,
          'batchOpId': batchOpId,
          'targetCount': results.length,
          'successCount': okCount,
        },
      );
      if (!mounted) return;
      if (okCount == 0) {
        final firstMsg = results.firstOrNull?.message;
        AppToast.show(
          context,
          results.length == 1 && firstMsg != null && firstMsg.isNotEmpty
              ? firstMsg
              : '签到未成功，请查看结果后重试',
          error: true,
        );
      } else {
        AppToast.show(context, '完成：$okCount/${results.length} 成功');
      }
      if (!_singleAssist) await _prepareEligible();
    } catch (error, stack) {
      AppLog.logAppError(error: error, stackTrace: stack, source: 'qr.batch');
      if (mounted) {
        AppToast.show(context, '提交未完成，请查看结果后重试', error: true);
      }
    } finally {
      // The classroom token rotates: retries must obtain a fresh scan.
      if (mounted) {
        setState(() {
          _submitting = false;
          _dataCtrl.clear();
        });
      }
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
    final primary = ref
        .watch(assistControllerProvider)
        .identities
        .where((a) => a.userId == widget.assistUserId)
        .firstOrNull;
    ref.listen(assistControllerProvider, (previous, next) {
      final before = previous?.identities.map((a) => a.userId).join(',');
      final after = next.identities.map((a) => a.userId).join(',');
      if ((before != after || previous?.ready != next.ready) &&
          !_singleAssist &&
          !_loadingEligible &&
          !_submitting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _prepareEligible();
        });
      }
    });

    return SubpageScaffold(
      hasUnsavedChanges: () => _dataCtrl.text.trim().isNotEmpty,
      isBusy: () => _submitting,
      title: '二维码签到',
      body: AppPageViewport(
        builder: (context, contentInsets) => ListView(
          padding:
              contentInsets +
              EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                AppSpace.md,
                AppSpace.pageXOf(context),
                AppSpace.xl,
              ),
          children: [
            Panel(
              lifted: true,
              outlined: true,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTruncatedText(
                          item.courseTitle,
                          style: AppTypography.cardTitle.copyWith(color: p.ink),
                        ),
                        if (item.createdByName.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '发起人：${item.createdByName}',
                            style: AppTypography.body.copyWith(color: p.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppStatusBadge(
                    item.isExpired
                        ? '已结束'
                        : item.isAnswered
                        ? '已签到'
                        : '进行中',
                    tone: item.isExpired
                        ? AppStatusTone.neutral
                        : item.isAnswered
                        ? AppStatusTone.success
                        : AppStatusTone.accent,
                    pill: true,
                  ),
                ],
              ),
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
                header: '为谁签到',
                children: [
                  AppCheckboxRow(
                    label:
                        primary?.displayName ??
                        ref.watch(authControllerProvider).profile?.name ??
                        '我',
                    value: _includeOwner,
                    trailing: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onChanged: _submitting || _loadingEligible || _primaryDone
                        ? null
                        : (value) => setState(() => _includeOwner = value),
                    title: Row(
                      children: [
                        AppIdentityAvatar(
                          name:
                              primary?.displayName ??
                              ref.watch(authControllerProvider).profile?.name,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                primary?.displayName ??
                                    ref
                                        .watch(authControllerProvider)
                                        .profile
                                        ?.name ??
                                    '我',
                                style: AppTypography.body.copyWith(
                                  fontSize: AppDensity.isTouch(context)
                                      ? 17
                                      : 15,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryDone ? p.muted : p.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.assistUserId == null ? '主账号' : '协助账号',
                                style: AppTypography.caption.copyWith(
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    accessory: _primaryDone
                        ? const AppStatusBadge(
                            '已签到或已结束',
                            tone: AppStatusTone.success,
                            pill: true,
                          )
                        : null,
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
                    AppCheckboxRow(
                      label: row.identity.displayName,
                      value: _selectedAssist.contains(row.identity.userId),
                      trailing: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      onChanged:
                          _submitting || _loadingEligible || !row.canSelect
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _selectedAssist.add(row.identity.userId);
                              } else {
                                _selectedAssist.remove(row.identity.userId);
                              }
                            }),
                      title: Row(
                        children: [
                          AppIdentityAvatar(name: row.identity.displayName),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.identity.displayName,
                                  style: AppTypography.body.copyWith(
                                    fontSize: AppDensity.isTouch(context)
                                        ? 17
                                        : 15,
                                    fontWeight: FontWeight.w600,
                                    color: row.canSelect ? p.ink : p.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '协助账号',
                                  style: AppTypography.caption.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      accessory: row.canSelect
                          ? null
                          : AppStatusBadge(
                              _eligLabel(row.eligibility),
                              tone:
                                  row.eligibility ==
                                      AssistQrEligibility.signedOrDone
                                  ? AppStatusTone.success
                                  : AppStatusTone.neutral,
                              pill: true,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            if (!_cameraSupported) ...[
              SettingsSection(
                header: '二维码内容',
                padTop: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _dataCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '粘贴二维码内容或识别后的签到链接',
                            fillColor: p.controlSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _pasteClipboard,
                            icon: const Icon(AppIcons.paste, size: 16),
                            label: const Text('从剪贴板粘贴'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            LayoutBuilder(
              builder: (context, bounds) {
                final primaryAction = FilledButton.icon(
                  onPressed: _submitting || _scanning || _loadingEligible
                      ? null
                      : _scanAndSubmit,
                  icon: Icon(
                    _cameraSupported || _desktopSupported
                        ? Icons.qr_code_scanner
                        : AppIcons.submit,
                    size: 18,
                  ),
                  label: Text(
                    _submitting
                        ? '提交中…'
                        : _loadingEligible
                        ? '正在核对名单…'
                        : _cameraSupported || _desktopSupported
                        ? '扫码签到（${_buildTargets().length}人）'
                        : '确认并提交',
                  ),
                );
                final secondaryAction = OutlinedButton(
                  onPressed: _submitting || _loadingEligible
                      ? null
                      : () async {
                          if (_dataCtrl.text.trim().isEmpty) {
                            await _pasteClipboard();
                          }
                          if (_dataCtrl.text.trim().isNotEmpty) {
                            await _submit();
                          }
                        },
                  child: const Text('粘贴内容并提交'),
                );
                final hasScanner = _cameraSupported || _desktopSupported;
                if (bounds.maxWidth >=
                    560 * MediaQuery.textScalerOf(context).scale(1)) {
                  return Row(
                    children: [
                      if (hasScanner) secondaryAction,
                      const Spacer(),
                      primaryAction,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primaryAction,
                    if (hasScanner) ...[
                      const SizedBox(height: 12),
                      secondaryAction,
                      const SizedBox(height: 16),
                      Text(
                        '扫码后为所选账号提交签到',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              SettingsSection(
                padTop: false,
                header: '结果',
                children: [
                  for (final r in _results)
                    SettingsRow(
                      leading: Icon(
                        r.ok ? AppIcons.checkCircle : AppIcons.error,
                        color: r.ok ? p.success : p.danger,
                      ),
                      title: r.target.label,
                      subtitle: r.message ?? (r.ok ? '成功' : '失败'),
                      trailing: r.ok
                          ? null
                          : TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _includeOwner = false;
                                        _selectedAssist.clear();
                                        if (r.target.key ==
                                            (widget.assistUserId == null
                                                ? SessionKey.owner
                                                : SessionKey.assist(
                                                    widget.assistUserId!,
                                                  ))) {
                                          _includeOwner = true;
                                        } else {
                                          _selectedAssist.add(r.target.userId);
                                        }
                                      });
                                      _scanAndSubmit();
                                    },
                              child: Text(
                                _cameraSupported || _desktopSupported
                                    ? '重新扫码'
                                    : '重新提交',
                              ),
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
