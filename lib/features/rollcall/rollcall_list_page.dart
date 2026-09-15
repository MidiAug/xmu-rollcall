import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RollcallTile(item: items[i]),
          );
        },
      ),
    );

    if (embedded) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '刷新',
              onPressed: () =>
                  ref.read(activeRollcallsProvider.notifier).refresh(),
              icon: Icon(Icons.refresh_rounded, color: palette.muted),
            ),
          ),
          Expanded(child: list),
        ],
      );
    }

    return PageScaffold(
      title: '进行中签到',
      subtitle: '下拉刷新 · 数字 / 雷达可点开应答',
      showHeader: wide,
      trailing: IconButton(
        tooltip: '刷新',
        onPressed: () => ref.read(activeRollcallsProvider.notifier).refresh(),
        icon: Icon(Icons.refresh_rounded, color: palette.muted),
      ),
      child: list,
    );
  }
}

class _RollcallTile extends StatefulWidget {
  const _RollcallTile({required this.item});

  final RollcallItem item;

  @override
  State<_RollcallTile> createState() => _RollcallTileState();
}

class _RollcallTileState extends State<_RollcallTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover ? palette.surfaceHigh : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? palette.selected : palette.borderStrong,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (item.type == RollcallType.qrcode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('二维码签到将在 Phase 3 支持')),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RollcallAnswerPage(item: item),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.typeLabel,
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.courseTitle.isEmpty ? '未命名课程' : item.courseTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.createdByName} · ${item.isAnswered ? "已签到" : "待签到"}'
                          '${item.isExpired ? " · 已结束" : ""}',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: palette.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
