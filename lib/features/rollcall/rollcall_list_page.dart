import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class RollcallListPage extends ConsumerWidget {
  const RollcallListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      return _SignedOutHint(
        onLogin: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          );
        },
      );
    }

    final async = ref.watch(activeRollcallsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(activeRollcallsProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('拉取失败：$e'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(activeRollcallsProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '当前没有进行中的签到',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '下拉刷新，或在「监控」页开启轮询。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RollcallTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _SignedOutHint extends StatelessWidget {
  const _SignedOutHint({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('登录后查看进行中签到', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onLogin, child: const Text('去登录')),
          ],
        ),
      ),
    );
  }
}

class _RollcallTile extends StatelessWidget {
  const _RollcallTile({required this.item});

  final RollcallItem item;

  @override
  Widget build(BuildContext context) {
    final accent = item.isRadar
        ? AppColors.accent
        : item.isNumber
            ? AppColors.primary
            : AppColors.muted;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.typeLabel,
                  style: TextStyle(
                    color: accent,
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.createdByName} · ${item.isAnswered ? "已签到" : "待签到"}'
                      '${item.isExpired ? " · 已结束" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
