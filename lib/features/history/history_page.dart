import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider);

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '本机尚无签到记录。\n成功或失败的提交会保存在此（不上云）。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => ref.read(historyProvider.notifier).clear(),
            child: const Text('清空'),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: ListTile(
                  leading: Icon(
                    e.ok ? Icons.check_circle : Icons.cancel_outlined,
                    color: e.ok ? AppColors.primary : AppColors.danger,
                  ),
                  title: Text(e.courseTitle.isEmpty ? '#${e.rollcallId}' : e.courseTitle),
                  subtitle: Text(
                    '${e.typeLabel} · ${e.at.toLocal().toString().substring(0, 19)}'
                    '${e.detail != null ? " · ${e.detail}" : ""}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
