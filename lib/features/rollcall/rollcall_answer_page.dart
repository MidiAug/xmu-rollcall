import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/coord_transform.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/features/rollcall/radar_place_card.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

Future<bool?> showRadarAnswerDialog(
  BuildContext context, {
  required RollcallItem item,
  int? assistUserId,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RollcallAnswerPage(
    item: item,
    assistUserId: assistUserId,
    mapDialog: true,
  ),
);

class RollcallAnswerPage extends ConsumerStatefulWidget {
  const RollcallAnswerPage({
    super.key,
    required this.item,
    this.assistUserId,
    this.previewMode = false,
    this.initialNumberCode,
    this.mapDialog = false,
  });

  final RollcallItem item;

  /// When set, submit via assist session jar / deviceId.
  final int? assistUserId;

  /// Debug-only: confirm UI without calling the rollcall API.
  final bool previewMode;

  /// Already discovered code offered for review; never submitted on entry.
  final String? initialNumberCode;
  final bool mapDialog;

  @override
  ConsumerState<RollcallAnswerPage> createState() => _RollcallAnswerPageState();
}

class _RollcallAnswerPageState extends ConsumerState<RollcallAnswerPage> {
  int? get _locationUserId =>
      widget.assistUserId ?? ref.read(authControllerProvider).profile?.id;

  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  bool _locating = false;
  int _mapRevision = 0;
  LatLng? _mapInitial;
  int? _ownerAtOpen;
  int? _selectedAtOpen;
  int _locationRequest = 0;
  RadarGeoSelection? _selection;
  String? _status;
  String? _radarFailure;
  bool _locationRejected = false;
  bool _pinnedByUser = false;
  String? _meetingKey;
  int? _scopeOwnerId;
  bool _scopePrepared = false;
  Future<void>? _scopeReady;
  late final DateTime _openedAt = ref.read(radarMeetingClockProvider)();

  @override
  void initState() {
    super.initState();
    _ownerAtOpen = ref.read(authControllerProvider).profile?.id;
    _selectedAtOpen = ref.read(selectedRollcallAccountProvider);
    if (widget.item.isNumber) _codeCtrl.text = widget.initialNumberCode ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.item.isRadar) _scopeReady ??= _prepareCoursePref();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _syncCoursePref() {
    if (!mounted || !widget.item.isRadar || _pinnedByUser || !_scopePrepared) {
      return;
    }
    final pref = ref
        .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
        .forCourse(
          courseId: widget.item.courseId,
          courseTitle: widget.item.courseTitle,
          meetingKey: _meetingKey ?? '',
        );
    if (pref == null) {
      if (_selection?.filledFrom == RadarFilledFrom.pref ||
          _selection?.filledFrom == RadarFilledFrom.configured) {
        setState(() {
          _selection = null;
          _mapInitial = null;
          _mapRevision++;
        });
      }
      return;
    }
    final next = selectionFromCoursePref(
      pref,
      ref.read(knownLocationsForUserProvider(_locationUserId)),
    );
    final cur = _selection;
    if (cur != null &&
        (cur.filledFrom == RadarFilledFrom.pref ||
            cur.filledFrom == RadarFilledFrom.configured) &&
        cur.filledFrom == next.filledFrom &&
        cur.latitude == next.latitude &&
        cur.longitude == next.longitude &&
        cur.obtainedVia == next.obtainedVia &&
        cur.placeId == next.placeId &&
        cur.label == next.label) {
      return;
    }
    setState(() {
      _selection = next;
      _mapInitial = LatLng(next.latitude, next.longitude);
      _mapRevision++;
    });
  }

  Future<void> _prepareCoursePref() async {
    final owner = ref.read(authControllerProvider).profile?.id;
    final controller = ref.read(
      courseRadarDefaultsForProvider(widget.assistUserId).notifier,
    );
    await controller.reload();
    final meeting = owner == null
        ? null
        : await resolveRadarMeeting(
            ownerId: owner,
            assistUserId: widget.assistUserId,
            courseId: widget.item.courseId,
            at: radarActivityReferenceTime(widget.item, _openedAt),
          );
    if (!mounted ||
        owner != _ownerAtOpen ||
        ref.read(authControllerProvider).profile?.id != owner) {
      return;
    }
    _meetingKey = meeting;
    _scopeOwnerId = owner;
    _scopePrepared = true;
    // A correction dialog starts with a fresh selection, never with a preset
    // that the user has just been asked to correct.
    if (!widget.mapDialog) _syncCoursePref();
  }

  void _pin(RadarGeoSelection selection) {
    _locationRequest++;
    setState(() {
      _pinnedByUser = true;
      _selection = selection.copyWith(filledFrom: RadarFilledFrom.user);
      if (selection.obtainedVia != RadarObtainedVia.map) {
        _mapInitial = LatLng(selection.latitude, selection.longitude);
        _mapRevision++;
      }
      _status = null;
    });
  }

  Future<bool> _confirm(String summary) {
    return showAppConfirmDialog(
      context,
      title: '确认提交签到',
      message: summary,
      confirmLabel: '确认提交',
    );
  }

  Future<void> _submitNumber() async {
    if (_submitting || widget.item.isExpired || widget.item.isAnswered) return;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      AppToast.show(context, '请输入数字签到码');
      return;
    }
    final opId = RollcallLog.newOpId();
    final session = widget.assistUserId == null ? 'owner' : 'assist';
    final confirmed = await _confirm(
      '课程：${widget.item.courseTitle}\n类型：数字\n签到码：$code\n\n仅本人到课操作。',
    );
    if (!confirmed) {
      RollcallLog.cancel(
        opId: opId,
        type: 'number',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      return;
    }
    setState(() => _submitting = true);
    final started = DateTime.now();
    bool? ok;
    try {
      RollcallLog.start(
        opId: opId,
        type: 'number',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      RollcallLog.numberCode(opId: opId, numberCode: code);
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .answerNumber(
            rollcallId: widget.item.rollcallId,
            numberCode: code,
            opId: opId,
          );
      ok = result.ok;
      if (result.ok && mounted) {
        ref
            .read(activeRollcallsProvider(widget.assistUserId).notifier)
            .patchItem(
              widget.item.copyWith(
                numberCode: code,
                clearNumberCodeError: true,
              ),
            );
      }
      await ref
          .read(ref.read(localHistoryForProvider(widget.assistUserId)).notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: widget.item.rollcallId,
              courseTitle: widget.item.courseTitle,
              typeLabel: '数字',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted) return;
      AppToast.show(
        context,
        result.message ?? (result.ok ? '成功' : '失败'),
        error: !result.ok,
      );
      if (result.ok) Navigator.of(context).pop();
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      AppToast.show(context, '签到未完成，请重试', error: true);
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

  Future<void> _useSystemLocation() async {
    if (_locating) return;
    _locating = true;
    final request = ++_locationRequest;
    final opId = RollcallLog.newOpId();
    bool current() => mounted && request == _locationRequest;
    void fail(String reason, String message) {
      RollcallLog.locationFail(opId: opId, reason: reason);
      if (current()) setState(() => _status = message);
    }

    setState(() => _status = '获取定位…');
    try {
      final service = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 10),
      );
      if (!current()) return;
      if (!service) {
        fail('service_off', '请打开定位，或在地图上选择位置');
        return;
      }
      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 10),
      );
      if (!current()) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!current()) return;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        fail(
          permission == LocationPermission.deniedForever
              ? 'permission_denied_forever'
              : 'permission_denied',
          '无法获取定位，可在地图上选择位置',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      ).timeout(const Duration(seconds: 20));
      if (!current()) return;
      if (!pos.latitude.isFinite ||
          !pos.longitude.isFinite ||
          !pos.accuracy.isFinite ||
          pos.accuracy <= 0) {
        throw const FormatException('系统返回无效定位');
      }
      // Keep system positions aligned with existing GCJ-02 map selections.
      final gcj = wgs84ToGcj02(pos.latitude, pos.longitude);
      _pin(
        RadarGeoSelection(
          latitude: gcj.latitude,
          longitude: gcj.longitude,
          accuracy: pos.accuracy,
          obtainedVia: RadarObtainedVia.device,
          filledFrom: RadarFilledFrom.user,
        ),
      );
    } catch (error, stack) {
      RollcallLog.locationFail(
        opId: opId,
        reason: error is TimeoutException
            ? 'position_timeout'
            : 'position_error',
        error: error,
        stackTrace: stack,
      );
      if (current()) {
        setState(
          () => _status = error is TimeoutException
              ? '定位超时，请重试或在地图上选点'
              : '定位失败，请重试或在地图上选点',
        );
      }
    } finally {
      _locating = false;
    }
  }

  Future<void> _useMapPick() async {
    final initial = _selection == null
        ? null
        : LatLng(_selection!.latitude, _selection!.longitude);
    final result = await Navigator.of(context).push<MapPickResult>(
      AppPageRoutes.build(MapPickPage(initial: initial, title: '选择位置')),
    );
    if (result == null || !mounted) return;
    final note = result.saveNote?.trim() ?? '';
    if (note.isNotEmpty) {
      final place = await ref
          .read(
            ref.read(savedLocationsForUserProvider(_locationUserId)).notifier,
          )
          .add(
            note: note,
            latitude: result.latitude,
            longitude: result.longitude,
          );
      if (!mounted) return;
      _pin(
        RadarGeoSelection(
          latitude: place.latitude,
          longitude: place.longitude,
          accuracy: place.accuracy,
          obtainedVia: RadarObtainedVia.place,
          placeId: place.id,
          label: place.note,
          filledFrom: RadarFilledFrom.user,
        ),
      );
      return;
    }
    _pin(
      RadarGeoSelection(
        latitude: result.latitude,
        longitude: result.longitude,
        accuracy: 35,
        obtainedVia: RadarObtainedVia.map,
        filledFrom: RadarFilledFrom.user,
      ),
    );
  }

  Future<void> _usePreset() async {
    final list = ref.read(knownLocationsForUserProvider(_locationUserId));
    final picked = await pickSavedLocation(
      context,
      list,
      userId: _locationUserId,
    );
    if (picked == null || !mounted) return;
    _pin(picked);
  }

  Future<void> _changeLocation() async {
    final action = await showRadarLocationSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case RadarLocationAction.device:
        await _useSystemLocation();
      case RadarLocationAction.map:
        await _useMapPick();
      case RadarLocationAction.preset:
        await _usePreset();
    }
  }

  Future<void> _submitRadar() async {
    if (_submitting || widget.item.isExpired || widget.item.isAnswered) return;
    final sel = _selection;
    if (sel == null) {
      AppToast.show(context, '请先选择位置');
      return;
    }
    final opId = RollcallLog.newOpId();
    final session = widget.assistUserId == null ? 'owner' : 'assist';
    // The map picker's bottom action is the explicit submission step.
    final confirmed =
        widget.mapDialog || Theme.of(context).platform == TargetPlatform.android
        ? true
        : await _confirm(
            '课程：${widget.item.courseTitle}\n'
            '${sel.confirmLine}\n'
            '${sel.latitude.toStringAsFixed(5)}, ${sel.longitude.toStringAsFixed(5)}'
            '${widget.previewMode ? "\n\n（预览模式，不会提交到服务器）" : ""}',
          );
    if (!confirmed) {
      RollcallLog.cancel(
        opId: opId,
        type: 'radar',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      return;
    }
    if (!mounted) return;

    if (widget.previewMode) {
      AppToast.show(context, '预览模式：未向服务器提交');
      return;
    }

    setState(() => _submitting = true);
    final started = DateTime.now();
    bool? ok;
    try {
      RollcallLog.start(
        opId: opId,
        type: 'radar',
        rollcallId: widget.item.rollcallId,
        courseTitle: widget.item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      final source = switch (sel.obtainedVia) {
        RadarObtainedVia.device => 'system',
        RadarObtainedVia.map => 'map',
        RadarObtainedVia.place => 'preset',
      };
      await (_scopeReady ??= _prepareCoursePref());
      if (!mounted) return;
      final owner = _scopeOwnerId;
      void requireOwner() {
        final auth = ref.read(authControllerProvider);
        if (!mounted ||
            owner == null ||
            owner != _ownerAtOpen ||
            !auth.isSignedIn ||
            auth.profile?.id != owner ||
            ref.read(selectedRollcallAccountProvider) != _selectedAtOpen) {
          throw StateError('账号已切换，请重新打开签到页');
        }
      }

      requireOwner();
      RollcallLog.location(
        opId: opId,
        source: source,
        latitude: sel.latitude,
        longitude: sel.longitude,
        accuracyM: sel.accuracy,
      );
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .answerRadar(
            rollcallId: widget.item.rollcallId,
            latitude: sel.latitude,
            longitude: sel.longitude,
            accuracy: sel.accuracy,
            opId: opId,
            beforeSend: () async => requireOwner(),
          );
      ok = result.ok;
      if (!mounted ||
          ref.read(authControllerProvider).profile?.id != owner ||
          ref.read(selectedRollcallAccountProvider) != _selectedAtOpen) {
        return;
      }
      // Updating a visible list must not create a provider and fetch it again.
      if (result.ok &&
          ref.exists(activeRollcallsProvider(widget.assistUserId))) {
        ref
            .read(activeRollcallsProvider(widget.assistUserId).notifier)
            .patchItem(widget.item.copyWith(status: 'on_call_fine'));
      }
      await ref
          .read(ref.read(localHistoryForProvider(widget.assistUserId)).notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: widget.item.rollcallId,
              courseTitle: widget.item.courseTitle,
              typeLabel: '雷达',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted ||
          ref.read(selectedRollcallAccountProvider) != _selectedAtOpen) {
        return;
      }
      if (!widget.mapDialog || result.ok) {
        AppToast.show(
          context,
          result.message ?? (result.ok ? '签到成功' : '签到失败'),
          error: !result.ok,
        );
      }
      if (result.ok) {
        await ref
            .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
            .rememberSuccess(
              courseTitle: widget.item.courseTitle,
              courseId: widget.item.courseId,
              latitude: sel.latitude,
              longitude: sel.longitude,
              accuracy: sel.accuracy,
              placeId: sel.placeId,
              obtainedVia: sel.obtainedVia,
              labelSnapshot: sel.label,
              meetingKey: _meetingKey ?? '',
              submittedAtMicros: started.microsecondsSinceEpoch,
            );
        if (mounted &&
            ref.read(authControllerProvider).profile?.id == owner &&
            ref.read(selectedRollcallAccountProvider) == _selectedAtOpen) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _status = '${result.message ?? "提交失败"}。可更换位置后重试。';
          _radarFailure = result.isLocationRejected
              ? '所选位置不符合本次签到范围，请重新选择上课位置。'
              : result.message ?? '服务未确认签到成功，请稍后重试。';
          _locationRejected = result.isLocationRejected;
          _mapInitial = LatLng(sel.latitude, sel.longitude);
        });
      }
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: widget.item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      if (ref.read(authControllerProvider).profile?.id != _ownerAtOpen ||
          ref.read(selectedRollcallAccountProvider) != _selectedAtOpen) {
        return;
      }
      // A local history/preference write must not turn an accepted submission
      // into a retry, which could send the same attendance twice.
      if (ok == true) {
        AppToast.show(context, '签到成功，本机记录未能完整保存');
        Navigator.of(context).pop(true);
        return;
      }
      if (widget.mapDialog) {
        setState(() {
          _radarFailure = requestFailureMessage(e);
          _locationRejected = false;
          _mapInitial = LatLng(sel.latitude, sel.longitude);
        });
      } else {
        AppToast.show(context, '签到未完成，请重试', error: true);
      }
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

  Future<void> _saveCourseLocation() async {
    final selection = _selection;
    final courseId = widget.item.courseId;
    if (selection == null ||
        courseId == null ||
        courseId.isEmpty ||
        _submitting) {
      return;
    }
    if (widget.previewMode) {
      AppToast.show(context, '预览模式：未保存课程位置');
      return;
    }
    setState(() => _submitting = true);
    try {
      await (_scopeReady ??= _prepareCoursePref());
      if (!mounted) return;
      if (_scopeOwnerId == null ||
          ref.read(authControllerProvider).profile?.id != _scopeOwnerId) {
        throw StateError('账号已切换，请重新打开签到页');
      }
      await ref
          .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
          .configureForCourse(
            courseId: courseId,
            courseTitle: widget.item.courseTitle,
            selection: selection,
            meetingKeys: [?_meetingKey],
          );
      if (mounted) AppToast.show(context, '已保存本课位置，开启自动签到后可使用');
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'radar_course_location',
      );
      if (mounted) AppToast.show(context, '课程位置未能保存，请重试', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = AppPalette.of(context);
    if (widget.mapDialog) return _radarDialog(context, p);
    ref.listen(
      ref.watch(savedLocationsForUserProvider(_locationUserId)),
      (_, _) => _syncCoursePref(),
    );
    ref.listen(
      courseRadarDefaultsForProvider(widget.assistUserId),
      (_, _) => _syncCoursePref(),
    );

    if (Theme.of(context).platform == TargetPlatform.android && item.isRadar) {
      return _androidRadarPicker(context, p);
    }

    return SubpageScaffold(
      hasUnsavedChanges: () =>
          _codeCtrl.text.trim().isNotEmpty || _pinnedByUser,
      isBusy: () => _submitting,
      title: widget.previewMode ? '雷达签到（预览）' : '${item.typeLabel}签到',
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
            if (widget.previewMode) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                '开发预览：不调用签到 API',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            if (item.isNumber) ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '数字签到码',
                  hintText: '老师口述的码',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton(
                onPressed:
                    (_submitting ||
                        widget.item.isExpired ||
                        widget.item.isAnswered)
                    ? null
                    : _submitNumber,
                child: Text(_submitting ? '提交中…' : '确认并提交'),
              ),
            ] else if (item.isRadar) ...[
              RadarPlaceCard(
                selection: _selection,
                onChange: _submitting ? null : _changeLocation,
              ),
              if (item.courseId?.isNotEmpty == true)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _submitting || _selection == null
                        ? null
                        : _saveCourseLocation,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('设为本课位置，供自动签到使用'),
                  ),
                ),
              if (_status != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_status!, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_submitting ||
                          _selection == null ||
                          widget.item.isExpired ||
                          widget.item.isAnswered)
                      ? null
                      : _submitRadar,
                  child: Text(
                    _submitting
                        ? '提交中…'
                        : (widget.previewMode ? '预览确认' : '用此位置签到'),
                  ),
                ),
              ),
            ] else
              const Text('暂不支持此签到类型'),
          ],
        ),
      ),
    );
  }

  Widget _radarDialog(BuildContext context, AppPalette p) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final height = (MediaQuery.sizeOf(context).height - 48).clamp(180.0, 620.0);
    return PopScope(
      canPop: !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _submitting) AppToast.show(context, '正在提交签到，请稍候');
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: p.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: BorderSide(color: p.border),
        ),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeInOutCubic,
          width: _radarFailure == null ? 760 : 420,
          child: AnimatedSize(
            duration: duration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _radarFailure == null
                  ? height
                  : height.clamp(180.0, 220.0),
              child: AnimatedSwitcher(
                duration: duration,
                child: _radarFailure == null
                    ? Column(
                        key: const ValueKey('radar-map-step'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '选择签到位置',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      AppTruncatedText(
                                        widget.item.courseTitle,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '取消',
                                  onPressed: _submitting
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: const Icon(AppIcons.close, size: 20),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: MapPickPanel(
                              key: ValueKey(_mapRevision),
                              initial: _mapInitial,
                              initialCampus: ref.watch(
                                radarCampusForUserProvider(_locationUserId),
                              ),
                              requireSelection: true,
                              busy: _submitting,
                              confirmLabel: _submitting ? '签到中…' : '签到',
                              onDraftChanged: (draft) => _pin(
                                RadarGeoSelection(
                                  latitude: draft.latitude,
                                  longitude: draft.longitude,
                                  accuracy: 35,
                                  obtainedVia: RadarObtainedVia.map,
                                ),
                              ),
                              onConfirm: (point) {
                                _pin(
                                  RadarGeoSelection(
                                    latitude: point.latitude,
                                    longitude: point.longitude,
                                    accuracy: 35,
                                    obtainedVia: RadarObtainedVia.map,
                                  ),
                                );
                                _submitRadar();
                              },
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        key: const ValueKey('radar-failure-step'),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _locationRejected ? '签到位置不匹配' : '签到未完成',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(_radarFailure!),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => setState(() {
                                      _radarFailure = null;
                                      _mapRevision++;
                                    }),
                                    child: const Text('重新选择'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _androidRadarPicker(BuildContext context, AppPalette p) {
    return SubpageScaffold(
      title: '选择位置',
      isBusy: () => _submitting,
      body: ColoredBox(
        color: p.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.courseTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                              ),
                            ),
                            if (widget.item.createdByName.isNotEmpty)
                              Text(
                                widget.item.createdByName,
                                style: TextStyle(fontSize: 13, color: p.muted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _locating ? '定位中…' : '当前位置',
                        color: p.muted,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        onPressed: _submitting || _locating
                            ? null
                            : _useSystemLocation,
                        icon: _locating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(AppIcons.location, size: 20),
                      ),
                      IconButton(
                        tooltip: '已保存地点',
                        color: p.muted,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        onPressed: _submitting ? null : _usePreset,
                        icon: const Icon(AppIcons.bookmark, size: 20),
                      ),
                    ],
                  ),
                  if (_status != null)
                    Text(
                      _status!,
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  if (widget.previewMode) const Text('预览，不会提交签到'),
                ],
              ),
            ),
            Expanded(
              child: MapPickPanel(
                key: ValueKey(_mapRevision),
                initial: _mapInitial,
                requireSelection: true,
                showCoordinates: false,
                campusSelectorPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                selectedLabel: _selection?.label,
                busy: _submitting,
                confirmLabel: _submitting ? '签到中…' : '签到',
                onDraftChanged: (draft) => _pin(
                  RadarGeoSelection(
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    accuracy: 35,
                    obtainedVia: RadarObtainedVia.map,
                    filledFrom: RadarFilledFrom.user,
                  ),
                ),
                onConfirm: (result) {
                  if (_selection == null ||
                      _selection!.latitude != result.latitude ||
                      _selection!.longitude != result.longitude) {
                    _pin(
                      RadarGeoSelection(
                        latitude: result.latitude,
                        longitude: result.longitude,
                        accuracy: 35,
                        obtainedVia: RadarObtainedVia.map,
                        filledFrom: RadarFilledFrom.user,
                      ),
                    );
                  }
                  _submitRadar();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
