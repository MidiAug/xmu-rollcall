import 'package:xmu_rollcall/app/campus_artwork.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
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
    final async = ref.watch(activeRollcallsProvider(scope));
    final list = AppPullToRefresh(
      color: palette.primary,
      onRefresh: () =>
          ref.read(activeRollcallsProvider(scope).notifier).refresh(),
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
                  FilledButton(
                    onPressed: () => ref
                        .read(activeRollcallsProvider(scope).notifier)
                        .refresh(),
                    child: const Text('重试'),
                  ),
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
                          detail: '下拉刷新，或开启自动检测',
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
                : _RollcallTile(
                    key: ValueKey(items[i].rollcallId),
                    item: items[i],
                    assistUserId: assistUserId,
                    enableAssistMulti: enableAssistMulti,
                    meeting: academicSchedule == null
                        ? null
                        : selectCampusMeetingForTitle(
                            academicSchedule!,
                            at ?? DateTime.now(),
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
      onRetry: () =>
          ref.read(activeRollcallsProvider(scope).notifier).refresh(),
      child: list,
    );
    if (embedded) return content;

    return PageScaffold(
      title: '进行中签到',
      showHeader: wide,
      trailing: AppRefreshButton(
        visualDensity: VisualDensity.compact,
        color: palette.muted,
        onRefresh: () =>
            ref.read(activeRollcallsProvider(scope).notifier).refresh(),
      ),
      child: content,
    );
  }
}

class _RollcallTile extends ConsumerStatefulWidget {
  const _RollcallTile({
    super.key,
    required this.item,
    this.assistUserId,
    this.enableAssistMulti = true,
    this.meeting,
  });

  final RollcallItem item;
  final int? assistUserId;
  final bool enableAssistMulti;
  final CampusMeeting? meeting;

  @override
  ConsumerState<_RollcallTile> createState() => _RollcallTileState();
}

class _RollcallTileState extends ConsumerState<_RollcallTile> {
  bool get _desktop => PlatformHooks.isDesktop && !AppDensity.isTouch(context);
  bool _hover = false;
  bool _submitting = false;

  Future<void> _oneClickNumber() async {
    final item = widget.item;
    if (_submitting || item.isExpired || item.isAnswered) return;
    final code = item.numberCode;
    if (code == null || code.isEmpty) {
      AppToast.show(context, item.numberCodeError ?? '尚无签到码，请下拉刷新或手填');
      return;
    }
    if (item.isAnswered) {
      AppToast.show(context, '已签到');
      return;
    }
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
      if (!mounted) return;
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
      if (!mounted) return;
      AppToast.show(context, '提交异常：$e', error: true);
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

  void _openSecondary() {
    final item = widget.item;
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
      RollcallAnswerPage(item: item, assistUserId: widget.assistUserId),
    );
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
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.fastCurve,
        decoration: BoxDecoration(
          color: _hover ? p.cardHover : p.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: _hover ? p.borderStrong : p.border),
        ),
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _identifyHeader(p, item, title),
            if (!item.isAnswered) ...[
              const SizedBox(height: AppSpace.xs),
              _attendance(item),
            ],
            if (item.isNumber) ...[
              const SizedBox(height: AppSpace.sm),
              _numberTaskStrip(p, item, wide: wide),
            ],
            if (item.type == RollcallType.unknown) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                '暂不支持此签到类型，可下拉刷新重试',
                style: TextStyle(fontSize: 12, height: 1.35, color: p.muted),
              ),
            ],
            if (!item.isAnswered && (item.courseId?.isNotEmpty ?? false))
              SessionPriorPanel(
                courseId: item.courseId!,
                assistUserId: widget.assistUserId,
                currentType: item.type,
              ),
          ],
        ),
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
                  if (!item.isAnswered)
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
                            if ((item.isExpired && !item.isAnswered) ||
                                (item.isAnswered &&
                                    item.type == RollcallType.unknown))
                              _statusChip(p, item)
                            else
                              Text(
                                '${item.typeLabel}签到',
                                style: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            const Spacer(),
                            if (!item.isAnswered &&
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
                                    : '${meeting.room.isEmpty ? '教室未提供' : meeting.room}  ·  ${hm(meeting.start)}–${hm(meeting.end)}',
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
                          if (!item.isAnswered)
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

  /// Completed tasks show their status at the action position, leaving the
  /// course title full width instead of repeating a status beside it.
  Widget _identifyHeader(AppPalette palette, RollcallItem item, String title) {
    final cta = _secondaryCta(item);
    final teacher = item.createdByName.trim();
    final metaStyle = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: palette.muted,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(palette),
                    ),
                  ),
                  if (!item.isAnswered ||
                      item.type == RollcallType.unknown) ...[
                    const SizedBox(width: AppSpace.xs),
                    _statusChip(palette, item),
                  ],
                ],
              ),
              if (teacher.isNotEmpty || item.typeLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(
                  [
                    if (teacher.isNotEmpty) teacher,
                    if (item.typeLabel.isNotEmpty) item.typeLabel,
                  ].join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ],
            ],
          ),
        ),
        if (cta != null) ...[const SizedBox(width: AppSpace.sm), cta],
      ],
    );
  }

  Widget? _secondaryCta(RollcallItem item) {
    if (item.isNumber) {
      if (item.isAnswered || _desktop) return null;
      return TextButton(
        onPressed: (_submitting || item.isAnswered || item.isExpired)
            ? null
            : _openSecondary,
        child: const Text('手动输入'),
      );
    }
    if (item.isAnswered && (item.isRadar || item.type == RollcallType.qrcode)) {
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
        onPressed: (item.isAnswered || item.isExpired) ? null : _openSecondary,
        child: const Text('选择位置'),
      );
    }
    if (item.type == RollcallType.qrcode) {
      return FilledButton(
        onPressed: (item.isAnswered || item.isExpired) ? null : _openSecondary,
        child: const Text('扫码签到'),
      );
    }
    return null;
  }

  Widget _statusChip(AppPalette palette, RollcallItem item) => AppStatusBadge(
    item.isExpired
        ? '已结束'
        : item.isAnswered
        ? '已签到'
        : '待签到',
    tone: item.isAnswered ? AppStatusTone.success : AppStatusTone.neutral,
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
            disabledBackgroundColor: item.isAnswered ? p.successSurface : null,
            disabledForegroundColor: item.isAnswered ? p.success : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          )
        : null,
    onPressed: (_submitting || item.isAnswered || item.isExpired)
        ? null
        : (item.numberCode?.isNotEmpty == true
              ? _oneClickNumber
              : _openSecondary),
    child: Text(
      _submitting
          ? '提交中…'
          : item.isAnswered
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
            child: item.isAnswered
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
        item.isAnswered || item.isExpired
            ? '暂无可用签到码'
            : err == null
            ? '正在获取签到码…'
            : '无法获取签到码，请手动输入',
        style: TextStyle(fontSize: 13, height: 1.35, color: palette.muted),
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
              if (!_desktop) ...[
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
