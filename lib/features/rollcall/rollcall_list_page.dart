import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class RollcallListPage extends ConsumerWidget {
  const RollcallListPage({super.key, this.embedded = false});

  /// When true, omit outer [PageScaffold] (used inside [RollcallHubPage]).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    if (!auth.isSignedIn) {
      final body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 48),
              const SizedBox(height: 16),
              Text(
                '尚未登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '使用学号与统一身份认证密码登录畅课',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => showLoginDialog(context),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('登录'),
              ),
            ],
          ),
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

    final async = ref.watch(activeRollcallsProvider);
    final list = RefreshIndicator(
      color: palette.primary,
      onRefresh: () => ref.read(activeRollcallsProvider.notifier).refresh(),
      child: async.when(
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
                    '拉取失败',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$e', style: TextStyle(color: palette.muted)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(activeRollcallsProvider.notifier).refresh(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyHint(
                  icon: Icons.inbox_outlined,
                  title: '暂无进行中的签到',
                  detail: '下拉刷新，或切换到「轮询」开启监控',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.pageX,
              AppSpace.xxs,
              AppSpace.pageX,
              AppSpace.xl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.stack),
            itemBuilder: (context, i) => _RollcallTile(item: items[i]),
          );
        },
      ),
    );

    if (embedded) return list;

    return PageScaffold(
      title: '进行中签到',
      subtitle: '数字一键签 · 雷达/二维码进二级页',
      showHeader: wide,
      trailing: IconButton(
        tooltip: '刷新',
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.read(activeRollcallsProvider.notifier).refresh(),
        icon: Icon(Icons.refresh_rounded, color: palette.muted),
      ),
      child: list,
    );
  }
}

class _RollcallTile extends ConsumerStatefulWidget {
  const _RollcallTile({required this.item});

  final RollcallItem item;

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
    try {
      final result = await ref.read(rollcallRepositoryProvider).answerNumber(
            rollcallId: item.rollcallId,
            numberCode: code,
          );
      await ref.read(historyProvider.notifier).add(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? (result.ok ? '成功' : '失败'))),
      );
      if (result.ok) {
        await ref.read(activeRollcallsProvider.notifier).refresh();
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

  void _openSecondary() {
    final item = widget.item;
    if (item.type == RollcallType.qrcode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('二维码扫描将在 Phase 3 支持')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RollcallAnswerPage(item: item),
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
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: _hover ? palette.surfaceHigh : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: item.isNumber
              ? (wide
                  ? _numberDesktopD1(palette, item, title)
                  : _numberMobile(palette, item, title))
              : _nonNumberBody(palette, item, title),
        ),
      ),
    );
  }

  Widget _typeChip(AppPalette palette, RollcallItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        item.typeLabel,
        style: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metaLine(AppPalette palette, RollcallItem item) {
    return Text(
      '${item.createdByName} · ${item.isAnswered ? "已签到" : "待签到"}'
      '${item.isExpired ? " · 已结束" : ""}',
      style: TextStyle(fontSize: 12, color: palette.muted),
    );
  }

  /// Wide D1: left course · center large copyable code · right CTA.
  Widget _numberDesktopD1(
    AppPalette palette,
    RollcallItem item,
    String title,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              _typeChip(palette, item),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    _metaLine(palette, item),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(child: _codeBlock(palette, item, large: true)),
        ),
        SizedBox(
          width: 128,
          child: FilledButton(
            onPressed: (_submitting || item.isAnswered) ? null : _oneClickNumber,
            child: Text(_submitting ? '提交中…' : '一键签到'),
          ),
        ),
      ],
    );
  }

  /// Narrow: title row, then left code + right button.
  Widget _numberMobile(
    AppPalette palette,
    RollcallItem item,
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _typeChip(palette, item),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  _metaLine(palette, item),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _codeBlock(palette, item, large: false)),
            const SizedBox(width: AppSpace.sm),
            FilledButton(
              onPressed:
                  (_submitting || item.isAnswered) ? null : _oneClickNumber,
              child: Text(_submitting ? '提交中…' : '一键签到'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _codeBlock(
    AppPalette palette,
    RollcallItem item, {
    required bool large,
  }) {
    final code = item.numberCode;
    final err = item.numberCodeError;
    if (code == null || code.isEmpty) {
      return Align(
        alignment: large ? Alignment.center : Alignment.centerLeft,
        child: Text(
          err ?? '正在获取签到码…',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      );
    }
    final text = Text(
      code,
      style: TextStyle(
        fontSize: large ? 28 : 22,
        fontWeight: FontWeight.w600,
        letterSpacing: large ? 4 : 2,
        color: palette.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (!large) return text;
    return Tooltip(
      message: '点击复制',
      child: InkWell(
        onTap: () => _copyCode(code),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              text,
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.copy_rounded, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nonNumberBody(
    AppPalette palette,
    RollcallItem item,
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _typeChip(palette, item),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  _metaLine(palette, item),
                ],
              ),
            ),
            if (item.isRadar)
              FilledButton.tonal(
                onPressed: item.isAnswered ? null : _openSecondary,
                child: const Text('选择位置'),
              ),
            if (item.type == RollcallType.qrcode)
              FilledButton.tonal(
                onPressed: item.isAnswered ? null : _openSecondary,
                child: const Text('扫描'),
              ),
          ],
        ),
        if (item.type == RollcallType.unknown) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            '未知类型，可下拉刷新',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ],
    );
  }
}
