import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_panel.dart';

class RollcallListPage extends ConsumerWidget {
  const RollcallListPage({
    super.key,
    this.embedded = false,
    this.assistUserId,
    this.enableAssistMulti = true,
  });

  /// When true, omit outer [PageScaffold] (used inside hub pages).
  final bool embedded;

  /// `null` = owner; otherwise assist identity userId.
  final int? assistUserId;

  /// When false (assist hub), QR page has no multi-person assist UI.
  final bool enableAssistMulti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final forAssist = assistUserId != null;

    if (!forAssist && !auth.isSignedIn) {
      final body = EmptyHint(
        icon: Icons.lock_outline,
        title: '尚未登录',
        detail: '使用学号与统一身份认证密码登录畅课',
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
                  Text('$e', style: TextStyle(color: palette.muted)),
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
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(
                    icon: Icons.inbox_outlined,
                    title: '暂无进行中的签到',
                    detail: '下拉刷新，或开启自动检测',
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpace.pageXOf(context),
              AppSpace.xxs,
              AppSpace.pageXOf(context),
              AppSpace.xl,
            ),
            itemCount: items.length,
            separatorBuilder: (context, _) =>
                SizedBox(height: AppSpace.stackOf(context)),
            itemBuilder: (context, i) => _RollcallTile(
              key: ValueKey(items[i].rollcallId),
              item: items[i],
              assistUserId: assistUserId,
              enableAssistMulti: enableAssistMulti,
            ),
          );
        },
      ),
    );

    if (embedded) return list;

    return PageScaffold(
      title: '进行中签到',
      showHeader: wide,
      trailing: AppRefreshButton(
        visualDensity: VisualDensity.compact,
        color: palette.muted,
        onRefresh: () =>
            ref.read(activeRollcallsProvider(scope).notifier).refresh(),
      ),
      child: list,
    );
  }
}

class _RollcallTile extends ConsumerStatefulWidget {
  const _RollcallTile({
    super.key,
    required this.item,
    this.assistUserId,
    this.enableAssistMulti = true,
  });

  final RollcallItem item;
  final int? assistUserId;
  final bool enableAssistMulti;

  @override
  ConsumerState<_RollcallTile> createState() => _RollcallTileState();
}

class _RollcallTileState extends ConsumerState<_RollcallTile> {
  bool _hover = false;
  bool _submitting = false;

  Future<void> _oneClickNumber() async {
    final item = widget.item;
    final code = item.numberCode;
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item.numberCodeError ?? '尚无签到码，请下拉刷新或手填'),
        ),
      );
      return;
    }
    if (item.isAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已签到')),
      );
      return;
    }
    setState(() => _submitting = true);
    final opId = RollcallLog.newOpId();
    final started = DateTime.now();
    final session =
        widget.assistUserId == null ? 'owner' : 'assist';
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
      final repo =
          ref.read(rollcallRepositoryForProvider(widget.assistUserId));
      final result = await repo.answerNumber(
        rollcallId: item.rollcallId,
        numberCode: code,
        opId: opId,
      );
      ok = result.ok;
      await ref.read(historyProvider.notifier).add(
            RollcallHistoryEntry(
              rollcallId: item.rollcallId,
              courseTitle: item.courseTitle,
              typeLabel: widget.assistUserId == null ? '数字' : '数字·协助',
              ok: result.ok,
              at: DateTime.now(),
              detail: result.message,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? (result.ok ? '成功' : '失败'))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交异常：$e')),
      );
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
      RollcallAnswerPage(
        item: item,
        assistUserId: widget.assistUserId,
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制签到码')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final item = widget.item;
    final title = item.courseTitle.isEmpty ? '未命名课程' : item.courseTitle;
    final wide =
        MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.fastCurve,
        decoration: BoxDecoration(
          color: _hover ? palette.cardHover : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: _hover ? palette.borderStrong : palette.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _identifyHeader(palette, item, title),
              if (item.isNumber) ...[
                const SizedBox(height: AppSpace.sm),
                _numberTaskStrip(palette, item, wide: wide),
              ],
              if (item.type == RollcallType.unknown) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  '暂不支持此签到类型，可下拉刷新重试',
                  style: TextStyle(fontSize: 12, height: 1.35, color: palette.muted),
                ),
              ],
              if (widget.assistUserId == null &&
                  (item.courseId?.isNotEmpty ?? false))
                SessionPriorPanel(
                  courseId: item.courseId!,
                  currentType: item.type,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Identify: title + status chip on L1; teacher + type (space, no `·`) on L2.
  Widget _identifyHeader(
    AppPalette palette,
    RollcallItem item,
    String title,
  ) {
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
                  const SizedBox(width: AppSpace.xs),
                  _statusChip(palette, item),
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
        if (cta != null) ...[
          const SizedBox(width: AppSpace.sm),
          cta,
        ],
      ],
    );
  }

  Widget? _secondaryCta(RollcallItem item) {
    if (item.isNumber) return null;
    if (item.isRadar) {
      return FilledButton(
        onPressed: item.isAnswered ? null : _openSecondary,
        child: const Text('选择位置'),
      );
    }
    if (item.type == RollcallType.qrcode) {
      return FilledButton(
        onPressed: item.isAnswered ? null : _openSecondary,
        child: const Text('扫描'),
      );
    }
    return null;
  }

  Widget _statusChip(AppPalette palette, RollcallItem item) {
    final answered = item.isAnswered;
    final expired = item.isExpired;
    final label = expired ? '已结束' : (answered ? '已签到' : '待签到');
    final Color fg;
    final Color bg;
    if (expired) {
      fg = palette.muted;
      bg = palette.surfaceHigh;
    } else if (answered) {
      fg = palette.primary;
      bg = palette.selected;
    } else {
      fg = palette.ink;
      bg = palette.hover;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1.2,
        ),
      ),
    );
  }

  TextStyle _titleStyle(AppPalette palette) {
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
      color: palette.ink,
    );
  }

  /// Task strip: large copyable code + primary CTA.
  Widget _numberTaskStrip(
    AppPalette palette,
    RollcallItem item, {
    required bool wide,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpace.sm,
        wide ? AppSpace.xs : 6,
        AppSpace.xs,
        wide ? AppSpace.xs : 6,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          Expanded(child: _codeAnchor(palette, item, wide: wide)),
          const SizedBox(width: AppSpace.sm),
          FilledButton(
            onPressed: (_submitting || item.isAnswered) ? null : _oneClickNumber,
            child: Text(_submitting ? '提交中…' : '一键签到'),
          ),
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
        err ?? '正在获取签到码…',
        style: TextStyle(fontSize: 13, height: 1.35, color: palette.muted),
      );
    }
    final text = Text(
      code,
      style: TextStyle(
        fontSize: wide ? 28 : 22,
        fontWeight: FontWeight.w600,
        letterSpacing: wide ? 4 : 2.5,
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
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.copy_rounded, size: 15, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
