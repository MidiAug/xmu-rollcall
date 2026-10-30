import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/location_validation_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/app/campus_artwork.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/refresh_feedback.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_panel.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

class RollcallListPage extends ConsumerWidget {
  const RollcallListPage({
    super.key,
    this.embedded = false,
    this.showUpdatedAt = true,
    this.assistUserId,
    this.enableAssistMulti = true,
    this.footer,
    this.academicSchedule,
    this.at,
    this.onRefresh,
  });

  /// When true, omit outer [PageScaffold] (used inside hub pages).
  final bool embedded;
  final bool showUpdatedAt;

  /// `null` = owner; otherwise assist identity userId.
  final int? assistUserId;

  /// When false (assist hub), QR page has no multi-person assist UI.
  final bool enableAssistMulti;

  /// Contextual, non-task content follows the tasks in the same scroll surface.
  final Widget? footer;
  final AcademicSchedule? academicSchedule;
  final DateTime? at;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final desktop = PlatformHooks.isDesktop && !AppDensity.isTouch(context);
    final forAssist = assistUserId != null;

    if (!forAssist && !auth.isSignedIn) {
      final body = EmptyHint(
        icon: Icons.lock_outline,
        title: '尚未登录',
        detail: auth.errorMessage ?? '使用学号与统一身份认证密码登录畅课',
        action: FilledButton.icon(
          onPressed: () => showLoginDialog(context),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('登录'),
        ),
      );
      if (embedded) return body;
      return PageScaffold(
        title: '进行中签到',
        subtitle: '登录后即可查看课堂签到',
        showHeader: wide,
        child: body,
      );
    }

    final scope = assistUserId;
    final refresh =
        onRefresh ??
        () => ref.read(activeRollcallsProvider(scope).notifier).refresh();
    final async = ref.watch(activeRollcallsProvider(scope));
    final list = AppPullToRefresh(
      color: palette.primary,
      onRefresh: refresh,
      child: async.when(
        skipError: true,
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加载失败',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requestFailureMessage(e),
                    style: TextStyle(color: palette.muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: refresh, child: const Text('重试')),
                ],
              ),
            ),
            ?footer,
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            if (async.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Expanded(
                        child: EmptyHint(
                          icon: Icons.inbox_outlined,
                          title: '暂无进行中的签到',
                          detail: '可手动刷新，发现的签到会显示在这里',
                        ),
                      ),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 24,
                          ),
                          child: footer!,
                        ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 24 : AppSpace.pageXOf(context),
              AppSpace.xxs,
              desktop ? 24 : AppSpace.pageXOf(context),
              AppSpace.xl,
            ),
            itemCount: items.length + (footer == null ? 0 : 1),
            separatorBuilder: (context, _) =>
                SizedBox(height: AppSpace.stackOf(context)),
            itemBuilder: (context, i) => i == items.length
                ? footer!
                : RollcallTaskCard(
                    key: ValueKey(items[i].rollcallId),
                    item: items[i],
                    assistUserId: assistUserId,
                    enableAssistMulti: enableAssistMulti,
                    meeting: academicSchedule == null
                        ? null
                        : selectCampusMeetingForTitle(
                            academicSchedule!,
                            radarActivityReferenceTime(
                              items[i],
                              at ?? DateTime.now(),
                            ),
                            items[i].courseTitle,
                          ),
                  ),
          );
        },
      ),
    );

    final content = RefreshFeedback(
      error: async.hasValue ? async.error : null,
      updatedAt: showUpdatedAt
          ? ref.read(activeRollcallsProvider(scope).notifier).lastUpdatedAt
          : null,
      onRetry: refresh,
      child: list,
    );
    if (embedded) return content;

    return PageScaffold(
      title: '进行中签到',
      showHeader: wide,
      trailing: AppRefreshButton(
        visualDensity: VisualDensity.compact,
        color: palette.muted,
        onRefresh: refresh,
      ),
      child: content,
    );
  }
}

class RollcallTaskCard extends ConsumerStatefulWidget {
  const RollcallTaskCard({
    super.key,
    required this.item,
    this.assistUserId,
    this.enableAssistMulti = true,
    this.meeting,
    this.mobileSummary,
  });

  final RollcallItem item;
  final int? assistUserId;
  final bool enableAssistMulti;
  final CampusMeeting? meeting;
  final String? mobileSummary;

  @override
  ConsumerState<RollcallTaskCard> createState() => _RollcallTileState();
}

typedef _RadarTaskLocation = ({
  CourseRadarPref? point,
  bool fromPreference,
  String? meeting,
});

class _RollcallTileState extends ConsumerState<RollcallTaskCard> {
  Object? _locationDisplayKey;
  Future<_RadarTaskLocation>? _locationDisplay;

  Future<_RadarTaskLocation> _resolveRadarLocation(
    int owner,
    DateTime at,
    VoidCallback requireCurrent,
  ) async {
    final item = widget.item;
    final meeting = await resolveRadarMeeting(
      ownerId: owner,
      assistUserId: widget.assistUserId,
      courseId: item.courseId,
      at: at,
    );
    var point = await readAutomaticRadarLocation(
      ownerId: owner,
      assistUserId: widget.assistUserId,
      courseId: item.courseId,
      meetingKey: meeting,
      at: at,
    );
    requireCurrent();
    final fromPreference = point != null;
    final classroom = widget.meeting;
    if (point == null &&
        classroom != null &&
        !at.isBefore(classroom.start.subtract(const Duration(minutes: 30))) &&
        !at.isAfter(classroom.end.add(const Duration(minutes: 30))) &&
        classroom.room.trim().isNotEmpty &&
        item.courseId?.isNotEmpty == true) {
      final user = widget.assistUserId ?? owner;
      await ref
          .read(ref.read(savedLocationsForUserProvider(user)).notifier)
          .ready;
      requireCurrent();
      final place = matchCoursePlace(
        classroom.room,
        ref.read(knownLocationsForUserProvider(user)),
      );
      if (place != null) {
        point = CourseRadarPref(
          courseTitle: item.courseTitle,
          courseId: item.courseId!,
          latitude: place.latitude,
          longitude: place.longitude,
          accuracy: place.accuracy,
          placeId: place.id,
          labelSnapshot: place.note,
          obtainedVia: RadarObtainedVia.place.storageKey,
          meetingKey: meeting ?? '',
        );
      }
    }
    if (point != null &&
        await isRejectedLocation(owner, widget.assistUserId ?? owner, point)) {
      point = null;
    }
    requireCurrent();
    return (point: point, fromPreference: fromPreference, meeting: meeting);
  }

  Widget _radarLocationSummary(AppPalette p) {
    final owner = ref.watch(authControllerProvider).profile?.id;
    final user = widget.assistUserId ?? owner;
    final preferences = ref.watch(
      courseRadarDefaultsForProvider(widget.assistUserId),
    );
    final places = ref.watch(ref.watch(savedLocationsForUserProvider(user)));
    final issues = ref.watch(locationIssuesForUserProvider(user));
    final key = (
      owner,
      widget.assistUserId,
      widget.item,
      widget.meeting,
      preferences,
      places,
      issues,
    );
    if (key != _locationDisplayKey) {
      _locationDisplayKey = key;
      _locationDisplay = owner == null
          ? null
          : _resolveRadarLocation(
              owner,
              radarActivityReferenceTime(widget.item, DateTime.now()),
              () {
                if (!mounted) throw StateError('页面已关闭');
              },
            );
    }
    return FutureBuilder<_RadarTaskLocation>(
      future: _locationDisplay,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final point = loading ? null : snapshot.data?.point;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              AppIcons.location,
              size: MediaQuery.textScalerOf(context).scale(18),
              color: p.ink,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loading
                    ? '正在确认签到位置…'
                    : point == null
                    ? (_answered ? '未保存签到位置' : '需补充签到位置')
                    : point.labelSnapshot.isNotEmpty
                    ? point.labelSnapshot
                    : '已保存的签到位置',
                style: TextStyle(color: p.ink, fontSize: 18, height: 1.4),
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _desktop => PlatformHooks.isDesktop && !AppDensity.isTouch(context);
  bool _hover = false;
  bool _submitting = false;
  (int?, int?, int)? _submittedFor;
  bool get _answered =>
      widget.item.isAnswered ||
      _submittedFor ==
          (
            ref.read(authControllerProvider).profile?.id,
            widget.assistUserId,
            widget.item.rollcallId,
          );

  Future<void> _manualNumberDialog() async {
    if (_submitting || _answered || widget.item.isExpired) return;
    final owner = ref.read(authControllerProvider).profile?.id;
    final scope = ref.read(selectedRollcallAccountProvider);
    final activity = widget.item.rollcallId;
    final code = await showAppPromptDialog(
      context,
      title: '输入签到码',
      message: widget.item.courseTitle,
      initialValue: widget.item.numberCode,
      hintText: '老师提供的签到码',
      keyboardType: TextInputType.number,
      confirmLabel: '签到',
      validator: (value) => value.trim().isEmpty ? '请输入签到码' : null,
    );
    if (code == null || !mounted) return;
    if (ref.read(authControllerProvider).profile?.id != owner ||
        ref.read(selectedRollcallAccountProvider) != scope ||
        widget.item.rollcallId != activity) {
      AppToast.show(context, '账号或签到已变化，请重新打开');
      return;
    }
    await _oneClickNumber(codeOverride: code.trim());
  }

  Future<void> _oneClickNumber({String? codeOverride}) async {
    final item = widget.item;
    if (_submitting || item.isExpired || _answered) return;
    final code = codeOverride ?? item.numberCode;
    if (code == null || code.isEmpty) {
      AppToast.show(context, item.numberCodeError ?? '尚无签到码，请下拉刷新或手填');
      return;
    }
    if (_answered) {
      AppToast.show(context, '已签到');
      return;
    }
    final owner = ref.read(authControllerProvider).profile?.id;
    final selection = ref.read(selectedRollcallAccountProvider);
    bool current() =>
        mounted &&
        ref.read(authControllerProvider).profile?.id == owner &&
        ref.read(selectedRollcallAccountProvider) == selection;
    setState(() => _submitting = true);
    final opId = RollcallLog.newOpId();
    final started = DateTime.now();
    final session = widget.assistUserId == null ? 'owner' : 'assist';
    bool? ok;
    try {
      RollcallLog.start(
        opId: opId,
        type: 'number',
        rollcallId: item.rollcallId,
        courseTitle: item.courseTitle,
        session: session,
        assistUserId: widget.assistUserId,
      );
      RollcallLog.numberCode(opId: opId, numberCode: code);
      final repo = ref.read(rollcallRepositoryForProvider(widget.assistUserId));
      final result = await repo.answerNumber(
        rollcallId: item.rollcallId,
        numberCode: code,
        opId: opId,
      );
      ok = result.ok;
      if (!current()) return;
      if (result.ok) {
        setState(
          () => _submittedFor = (owner, widget.assistUserId, item.rollcallId),
        );
        if (codeOverride != null &&
            ref.exists(activeRollcallsProvider(widget.assistUserId))) {
          ref
              .read(activeRollcallsProvider(widget.assistUserId).notifier)
              .patchItem(
                item.copyWith(
                  numberCode: code,
                  clearNumberCodeError: true,
                  status: 'on_call_fine',
                ),
              );
        }
      }
      await ref
          .read(ref.read(localHistoryForProvider(widget.assistUserId)).notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: item.rollcallId,
              courseTitle: item.courseTitle,
              typeLabel: '数字',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted || !current()) return;
      AppToast.show(
        context,
        result.message ?? (result.ok ? '成功' : '失败'),
        error: !result.ok,
      );
      if (result.ok) {
        await ref
            .read(activeRollcallsProvider(widget.assistUserId).notifier)
            .refresh();
      }
    } catch (e, st) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: item.rollcallId,
        error: e,
        stackTrace: st,
      );
      if (!mounted || !current()) return;
      AppToast.show(context, '签到未完成，请重试', error: true);
    } finally {
      RollcallLog.end(
        opId: opId,
        rollcallId: item.rollcallId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        ok: ok,
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _oneClickRadar() async {
    final item = widget.item;
    if (_submitting || _answered || item.isExpired) return;
    final owner = ref.read(authControllerProvider).profile?.id;
    final selection = ref.read(selectedRollcallAccountProvider);
    if (owner == null) return;
    bool current() =>
        mounted &&
        ref.read(authControllerProvider).profile?.id == owner &&
        ref.read(selectedRollcallAccountProvider) == selection;
    void requireCurrent() {
      if (!current()) throw StateError('账号已切换');
    }

    setState(() => _submitting = true);
    final started = DateTime.now();
    final opId = RollcallLog.newOpId();
    bool? ok;
    try {
      final at = radarActivityReferenceTime(item, started);
      final resolved = await _resolveRadarLocation(owner, at, requireCurrent);
      final point = resolved.point;
      final meeting = resolved.meeting;
      final fromPreference = resolved.fromPreference;
      if (point == null) {
        if (mounted && current()) _openSecondary();
        return;
      }
      requireCurrent();
      final submitted = point;
      Future<bool> pointUnchanged() async {
        if (fromPreference) {
          final latest = await readAutomaticRadarLocation(
            ownerId: owner,
            assistUserId: widget.assistUserId,
            courseId: item.courseId,
            meetingKey: meeting,
            at: at,
          );
          return latest != null &&
              latest.latitude == submitted.latitude &&
              latest.longitude == submitted.longitude &&
              latest.accuracy == submitted.accuracy;
        }
        final latest = matchCoursePlace(
          widget.meeting!.room,
          ref.read(knownLocationsForUserProvider(widget.assistUserId ?? owner)),
        );
        return latest != null &&
            latest.id == submitted.placeId &&
            latest.latitude == submitted.latitude &&
            latest.longitude == submitted.longitude &&
            latest.accuracy == submitted.accuracy;
      }

      RollcallLog.start(
        opId: opId,
        type: 'radar',
        rollcallId: item.rollcallId,
        courseTitle: item.courseTitle,
        session: widget.assistUserId == null ? 'owner' : 'assist',
        assistUserId: widget.assistUserId,
      );
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .answerRadar(
            rollcallId: item.rollcallId,
            latitude: submitted.latitude,
            longitude: submitted.longitude,
            accuracy: submitted.accuracy,
            opId: opId,
            beforeSend: () async {
              requireCurrent();
              if (widget.item.isExpired || _answered) {
                throw StateError('签到状态已改变');
              }
              if (!await pointUnchanged()) {
                throw StateError('签到位置已改变');
              }
              requireCurrent();
            },
          );
      ok = result.ok;
      if (!current()) return;
      if (result.ok) {
        setState(
          () => _submittedFor = (owner, widget.assistUserId, item.rollcallId),
        );
      }
      await ref
          .read(ref.read(localHistoryForProvider(widget.assistUserId)).notifier)
          .add(
            RollcallHistoryEntry(
              rollcallId: item.rollcallId,
              courseTitle: item.courseTitle,
              typeLabel: '雷达',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!current()) return;
      if (result.ok) {
        await ref
            .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
            .rememberSuccess(
              courseTitle: item.courseTitle,
              courseId: item.courseId,
              latitude: submitted.latitude,
              longitude: submitted.longitude,
              accuracy: submitted.accuracy,
              placeId: submitted.placeId,
              obtainedVia: RadarObtainedVia.values.firstWhere(
                (value) => value.storageKey == submitted.obtainedVia,
                orElse: () => RadarObtainedVia.map,
              ),
              labelSnapshot: submitted.labelSnapshot,
              meetingKey: submitted.meetingKey,
              submittedAtMicros: started.microsecondsSinceEpoch,
            );
        if (!current()) return;
        await ref
            .read(activeRollcallsProvider(widget.assistUserId).notifier)
            .refresh();
      } else if (result.isLocationRejected && await pointUnchanged()) {
        if (!current()) return;
        await recordLocationIssue(
          owner,
          widget.assistUserId ?? owner,
          submitted,
        );
        if (!current()) return;
        ref.invalidate(locationIssuesProvider);
      }
      if (mounted && current()) {
        AppToast.show(
          context,
          result.message ?? (result.ok ? '签到成功' : '签到失败，可更换位置后重试'),
          error: !result.ok,
        );
      }
    } catch (error, stack) {
      RollcallLog.exception(
        opId: opId,
        rollcallId: item.rollcallId,
        error: error,
        stackTrace: stack,
      );
      if (mounted && current()) {
        AppToast.show(context, '签到未完成，请重试或检查位置', error: true);
      }
    } finally {
      RollcallLog.end(
        opId: opId,
        rollcallId: item.rollcallId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        ok: ok,
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _mobileSubmit() {
    if (_submitting) return;
    if (Theme.of(context).platform != TargetPlatform.android) {
      _openSecondary(prefillNumber: true);
      return;
    }
    if (widget.item.isNumber && widget.item.numberCode?.isNotEmpty == true) {
      _oneClickNumber();
    } else if (widget.item.isRadar) {
      _oneClickRadar();
    } else {
      _openSecondary(prefillNumber: true);
    }
  }

  void _openSecondary({bool prefillNumber = false}) {
    final item = widget.item;
    if (Theme.of(context).platform == TargetPlatform.android && item.isNumber) {
      _manualNumberDialog();
      return;
    }
    if (item.type == RollcallType.qrcode) {
      AppPageRoutes.push(
        context,
        QrAnswerPage(
          item: item,
          assistUserId: widget.assistUserId,
          enableAssistMulti: widget.enableAssistMulti,
        ),
      );
      return;
    }
    AppPageRoutes.push(
      context,
      RollcallAnswerPage(
        item: item,
        assistUserId: widget.assistUserId,
        initialNumberCode: prefillNumber ? item.numberCode : null,
      ),
    ).then((_) {
      if (mounted) setState(() => _locationDisplayKey = null);
    });
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    AppToast.show(context, '已复制签到码');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final item = widget.item;
    final title = item.courseTitle.isEmpty ? '未命名课程' : item.courseTitle;
    if (_desktop) return _desktopCard(p, item, title);
    if (Theme.of(context).platform == TargetPlatform.android) {
      return _androidCard(p, item, title);
    }
    return _mobileCard(p, item, title);
  }

  Widget _androidCard(AppPalette p, RollcallItem item, String title) {
    final done = _answered;
    final unavailable = item.isExpired || item.type == RollcallType.unknown;
    final active = activeRollcallsProvider(widget.assistUserId);
    final fetchedAt = ref.exists(active)
        ? ref.read(active.notifier).lastUpdatedAt?.toLocal()
        : null;
    final updatedLabel = fetchedAt == null
        ? widget.mobileSummary
        : '更新于 ${fetchedAt.hour.toString().padLeft(2, '0')}:${fetchedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('mobile-rollcall-${item.rollcallId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.mobileOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    if (item.createdByName.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.createdByName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _attendance(item, compact: true),
                    if (updatedLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        updatedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: item.isNumber
                    ? Row(
                        children: [
                          Icon(
                            AppIcons.number,
                            size: MediaQuery.textScalerOf(context).scale(
                              item.numberCode?.isNotEmpty == true ? 22 : 18,
                            ),
                            color: p.ink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _codeAnchor(p, item, wide: false)),
                        ],
                      )
                    : item.isRadar
                    ? _radarLocationSummary(p)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            item.isQrcode ? AppIcons.qr : AppIcons.info,
                            size: MediaQuery.textScalerOf(context).scale(18),
                            color: p.ink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.isQrcode ? '二维码' : '暂不支持此签到类型',
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.4,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 16),
              if (item.isRadar)
                FutureBuilder<_RadarTaskLocation>(
                  future: _locationDisplay,
                  builder: (context, snapshot) => _androidActionButton(
                    item,
                    done: done,
                    unavailable: unavailable,
                    resolving:
                        snapshot.connectionState == ConnectionState.waiting,
                    hasLocation: snapshot.data?.point != null,
                  ),
                )
              else
                _androidActionButton(
                  item,
                  done: done,
                  unavailable: unavailable,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _androidActionButton(
    RollcallItem item, {
    required bool done,
    required bool unavailable,
    bool resolving = false,
    bool hasLocation = true,
  }) => SizedBox(
    width: 96,
    child: FilledButton(
      onPressed: done || unavailable || _submitting || resolving
          ? null
          : _mobileSubmit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        done
            ? '已签到'
            : item.isExpired
            ? '已结束'
            : _submitting
            ? '提交中…'
            : item.isQrcode
            ? '扫码'
            : item.isNumber && item.numberCode?.isNotEmpty != true
            ? '手动输入'
            : item.isRadar && !hasLocation && !resolving
            ? '选择位置'
            : '签到',
      ),
    ),
  );

  Widget _mobileCard(AppPalette p, RollcallItem item, String title) {
    final done = _answered;
    final unavailable = item.isExpired || item.type == RollcallType.unknown;
    final tone = done
        ? p.success
        : unavailable
        ? p.muted
        : p.primary;
    final room = widget.meeting?.room.trim();
    final subtitle = room?.isNotEmpty == true
        ? room!
        : item.createdByName.trim();
    return Container(
      key: ValueKey('mobile-rollcall-${item.rollcallId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  done
                      ? '签到完成'
                      : item.isExpired
                      ? '已结束'
                      : '待签到',
                  style: TextStyle(
                    color: tone,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                item.isRadar ? '定位签到' : '${item.typeLabel}签到',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
              if (item.courseId?.isNotEmpty == true && !done)
                _courseMenu(p, item),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: p.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  room?.isNotEmpty == true
                      ? AppIcons.location
                      : AppIcons.person,
                  size: 16,
                  color: p.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
          if (Theme.of(context).platform == TargetPlatform.android) ...[
            if (item.isNumber) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('签到码', style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(child: _codeAnchor(p, item, wide: false)),
                ],
              ),
            ],
            if (item.isRadar && !done && !unavailable) ...[
              const SizedBox(height: 12),
              _radarLocationSummary(p),
            ],
            const SizedBox(height: 12),
            _attendance(item, compact: true),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (widget.mobileSummary != null)
                Text(
                  widget.mobileSummary!,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              if (done)
                FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: p.successSurface,
                    disabledForegroundColor: p.success,
                    minimumSize: const Size(112, 48),
                  ),
                  child: const Text('已签到'),
                )
              else if (!unavailable)
                FilledButton.icon(
                  onPressed: _submitting ? null : _mobileSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 48),
                  ),
                  label: Text(_submitting ? '提交中…' : '去签到'),
                  icon: const Icon(AppIcons.right, size: 16),
                  iconAlignment: IconAlignment.end,
                )
              else if (item.type == RollcallType.unknown && !done)
                Text(
                  '暂不支持此签到类型',
                  style: TextStyle(color: p.muted, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendance(RollcallItem item, {bool compact = false}) =>
      AttendanceCountRow(
        key: ValueKey((
          ref.watch(authControllerProvider).profile?.id,
          widget.assistUserId,
          item.rollcallId,
        )),
        rollcallId: item.rollcallId,
        assistUserId: widget.assistUserId,
        expired: item.isExpired,
        completed:
            Theme.of(context).platform == TargetPlatform.android &&
            !_desktop &&
            _answered,
        compact: compact,
      );

  Widget _courseMenu(AppPalette p, RollcallItem item) => AppActionMenu<String>(
    tooltip: '课程操作',
    framed: false,
    enabled: !_submitting && !item.isExpired,
    onSelected: (value) {
      if (value == 'manual') {
        _openSecondary();
      } else {
        _showCourseReference();
      }
    },
    actions: [
      if (item.isNumber)
        const AppMenuAction('manual', '手动输入', icon: AppIcons.document),
      if (item.courseId?.isNotEmpty == true)
        const AppMenuAction('prior', '课堂参考', icon: AppIcons.history),
    ],
  );

  Widget _desktopCard(AppPalette p, RollcallItem item, String title) {
    final meeting = widget.meeting;
    String hm(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.fastCurve,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: p.primary.withValues(alpha: _hover ? .25 : .13),
          ),
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: p.isDark ? .02 : .045),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            p.surface,
                            p.isDark
                                ? Color.alphaBlend(
                                    p.primary.withValues(alpha: .08),
                                    p.surface,
                                  )
                                : const Color(0xFFD7FAF4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_answered)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 300,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: p.isDark ? .26 : .72,
                          child: CampusArtworkTreatment(
                            child: Image.asset(
                              'assets/illustrations/campus_mist.png',
                              cacheWidth: 768,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _titleStyle(p),
                              ),
                            ),
                            const SizedBox(width: 14),
                            if ((item.isExpired && !_answered) ||
                                (_answered &&
                                    item.type == RollcallType.unknown))
                              _statusChip(p, item)
                            else
                              Text(
                                '${item.typeLabel}签到',
                                style: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            const Spacer(),
                            if (!_answered &&
                                (item.isNumber ||
                                    item.courseId?.isNotEmpty == true))
                              _courseMenu(p, item),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              meeting == null
                                  ? AppIcons.person
                                  : AppIcons.location,
                              size: 17,
                              color: p.ink,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                meeting == null
                                    ? (item.createdByName.isEmpty
                                          ? '课堂签到'
                                          : item.createdByName)
                                    : '${meeting.room.isEmpty ? '教室未提供' : meeting.room}    ${hm(meeting.start)}–${hm(meeting.end)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: p.ink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(
                color: p.primary.withValues(alpha: .08),
                height: 1,
                indent: 22,
                endIndent: 22,
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: item.type == RollcallType.unknown
                    ? Text(
                        '暂不支持此签到类型，可下拉刷新重试',
                        style: TextStyle(fontSize: 12, color: p.muted),
                      )
                    : item.isNumber
                    ? _numberTaskStrip(p, item, wide: true)
                    : Row(
                        children: [
                          if (!_answered)
                            Expanded(child: _attendance(item, compact: true))
                          else
                            const Spacer(),
                          if (_secondaryCta(item) != null) _secondaryCta(item)!,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseReference() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '课堂参考',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: SessionPriorPanel(
                      courseId: widget.item.courseId!,
                      assistUserId: widget.assistUserId,
                      currentType: widget.item.type,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _secondaryCta(RollcallItem item) {
    if (item.isNumber) {
      if (_answered || _desktop) return null;
      return TextButton(
        onPressed: (_submitting || _answered || item.isExpired)
            ? null
            : _openSecondary,
        child: const Text('手动输入'),
      );
    }
    if (_answered && (item.isRadar || item.type == RollcallType.qrcode)) {
      final p = AppPalette.of(context);
      return FilledButton(
        style: FilledButton.styleFrom(
          disabledBackgroundColor: p.successSurface,
          disabledForegroundColor: p.success,
        ),
        onPressed: null,
        child: const Text('已签到'),
      );
    }
    if (item.isRadar) {
      return FilledButton(
        onPressed: (_answered || item.isExpired) ? null : _openSecondary,
        child: const Text('选择位置'),
      );
    }
    if (item.type == RollcallType.qrcode) {
      return FilledButton(
        onPressed: (_answered || item.isExpired) ? null : _openSecondary,
        child: const Text('扫码签到'),
      );
    }
    return null;
  }

  Widget _statusChip(AppPalette palette, RollcallItem item) => AppStatusBadge(
    item.isExpired
        ? '已结束'
        : _answered
        ? '已签到'
        : '待签到',
    tone: _answered ? AppStatusTone.success : AppStatusTone.neutral,
  );

  TextStyle _titleStyle(AppPalette palette) {
    return TextStyle(
      fontSize: _desktop ? 20 : 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
      color: palette.ink,
    );
  }

  Widget _numberAction(AppPalette p, RollcallItem item) => FilledButton(
    style: _desktop
        ? FilledButton.styleFrom(
            minimumSize: const Size(160, 44),
            disabledBackgroundColor: _answered ? p.successSurface : null,
            disabledForegroundColor: _answered ? p.success : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          )
        : null,
    onPressed: (_submitting || _answered || item.isExpired)
        ? null
        : (item.numberCode?.isNotEmpty == true
              ? _oneClickNumber
              : _openSecondary),
    child: Text(
      _submitting
          ? '提交中…'
          : _answered
          ? '已签到'
          : item.isExpired
          ? '已结束'
          : item.numberCode?.isNotEmpty == true
          ? (_desktop ? '确认签到' : '一键签到')
          : '输入签到码',
      style: _desktop ? const TextStyle(fontSize: 14) : null,
    ),
  );

  /// One row: code, live attendance and confirmed action. The mobile strip keeps
  /// its existing presentation while sharing the same submission handler.
  Widget _numberTaskStrip(
    AppPalette p,
    RollcallItem item, {
    required bool wide,
  }) {
    if (_desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 104 * MediaQuery.textScalerOf(context).scale(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('签到码', style: TextStyle(fontSize: 11, color: p.muted)),
                const SizedBox(height: 5),
                _codeAnchor(p, item, wide: true),
              ],
            ),
          ),
          Container(
            height: 44,
            width: 1,
            color: p.borderStrong,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _answered
                ? const SizedBox.shrink()
                : _attendance(item, compact: true),
          ),
          const SizedBox(width: 10),
          _numberAction(p, item),
        ],
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpace.sm,
        wide ? AppSpace.xs : 6,
        AppSpace.xs,
        wide ? AppSpace.xs : 6,
      ),
      decoration: BoxDecoration(
        color: p.content,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          Expanded(child: _codeAnchor(p, item, wide: wide)),
          const SizedBox(width: AppSpace.sm),
          _numberAction(p, item),
        ],
      ),
    );
  }

  Widget _codeAnchor(
    AppPalette palette,
    RollcallItem item, {
    required bool wide,
  }) {
    final code = item.numberCode;
    final err = item.numberCodeError;
    if (code == null || code.isEmpty) {
      return Text(
        Theme.of(context).platform == TargetPlatform.android &&
                !_desktop &&
                !_answered &&
                !item.isExpired
            ? '无法获取签到码'
            : _answered || item.isExpired
            ? '暂无可用签到码'
            : err == null
            ? '正在获取签到码…'
            : '无法获取签到码，请手动输入',
        style: TextStyle(
          fontSize:
              Theme.of(context).platform == TargetPlatform.android && !_desktop
              ? 18
              : 13,
          height: 1.4,
          color: palette.muted,
        ),
      );
    }
    final text = Text(
      code,
      style: TextStyle(
        fontSize: _desktop
            ? 36
            : wide
            ? 28
            : 22,
        fontFamily: _desktop ? 'Segoe UI' : null,
        fontWeight: FontWeight.w600,
        letterSpacing: _desktop
            ? -.7
            : wide
            ? 4
            : 2.5,
        height: 1.15,
        color: palette.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Tooltip(
      message: '点击复制',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _copyCode(code),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Flexible(child: text),
              if (!_desktop &&
                  Theme.of(context).platform != TargetPlatform.android) ...[
                const SizedBox(width: AppSpace.xs),
                Icon(Icons.copy_rounded, size: 15, color: palette.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
