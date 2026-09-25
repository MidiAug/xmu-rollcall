import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

/// 作业 Tab：只读待办列表。
class HomeworkHubPage extends ConsumerStatefulWidget {
  const HomeworkHubPage({super.key});

  @override
  ConsumerState<HomeworkHubPage> createState() => _HomeworkHubPageState();
}

class _HomeworkHubPageState extends ConsumerState<HomeworkHubPage>
    with ShellTabAware<HomeworkHubPage> {
  final _scroll = ScrollController();

  @override
  AppDestination get shellTab => AppDestination.homework;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void onShellTabVisible() {
    if (ref.read(authControllerProvider).isSignedIn) {
      ref.read(homeworkTodosProvider.notifier).ensureFresh();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openDetail(HomeworkItem item) {
    AppPageRoutes.push(context, HomeworkDetailPage(seed: item));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).isSignedIn;

    return PageScaffold(
      title: '作业',
      showHeader: false,
      child: AppContentColumn(
        child: PrimaryScrollController(
          controller: _scroll,
          child: !signedIn
              ? _SignedOutHint(onLogin: () => showLoginDialog(context))
              : _TodosBody(onOpen: _openDetail),
        ),
      ),
    );
  }
}

class _SignedOutHint extends StatelessWidget {
  const _SignedOutHint({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return EmptyHint(
      icon: Icons.lock_outline,
      title: '尚未登录',
      detail: '登录后可查看待办作业',
      action: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login, size: 18),
        label: const Text('登录'),
      ),
    );
  }
}

class _TodosBody extends ConsumerWidget {
  const _TodosBody({required this.onOpen});

  final ValueChanged<HomeworkItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final async = ref.watch(homeworkTodosProvider);

    return AppPullToRefresh(
      color: p.primary,
      onRefresh: () => ref.read(homeworkTodosProvider.notifier).refresh(),
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pageX),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拉取失败',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$e', style: TextStyle(color: p.muted)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(homeworkTodosProvider.notifier).refresh(),
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
                    icon: Icons.assignment_turned_in_outlined,
                    title: '暂无待办',
                    detail: '下拉刷新即可',
                  ),
                ),
              ],
            );
          }
          final upcoming =
              items.where((e) => !e.isOverdue).toList(growable: false);
          final overdue =
              items.where((e) => e.isOverdue).toList(growable: false);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pageX, AppSpace.sm, pageX, AppSpace.xl),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionLabel(label: '进行中 · ${upcoming.length}'),
                const SizedBox(height: AppSpace.xs),
                for (final item in upcoming)
                  _TodoTile(item: item, onTap: () => onOpen(item)),
              ],
              if (overdue.isNotEmpty) ...[
                if (upcoming.isNotEmpty) const SizedBox(height: AppSpace.md),
                _SectionLabel(label: '已过期 · ${overdue.length}'),
                const SizedBox(height: AppSpace.xs),
                for (final item in overdue)
                  _TodoTile(item: item, onTap: () => onOpen(item), overdue: true),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: p.muted,
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.onTap,
    this.overdue = false,
  });

  final HomeworkItem item;
  final VoidCallback onTap;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpace.stackOf(context) * 0.55),
      child: AppHoverSurface(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? '未命名作业' : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.3,
                      color: p.ink,
                    ),
                  ),
                  if (item.courseName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: p.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      item.dueLabel,
                      if (item.status.isNotEmpty) item.status,
                    ].join('  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                      color: overdue ? p.danger : p.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
          ],
        ),
      ),
    );
  }
}
