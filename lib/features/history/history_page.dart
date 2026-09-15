import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

enum HistorySegment { course, local }

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  HistorySegment _segment = HistorySegment.course;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final auth = ref.watch(authControllerProvider);
    final local = ref.watch(historyProvider);

    return PageScaffold(
      title: '\u8bb0\u5f55',
      subtitle: _segment == HistorySegment.course
          ? '\u8bfe\u7a0b\u7b7e\u5230\uff08\u7545\u8bfe\u670d\u52a1\u7aef\uff09'
          : '\u4ec5\u4fdd\u5b58\u5728\u672c\u673a\uff0c\u4e0d\u4e0a\u4e91',
      showHeader: wide,
      trailing: _segment == HistorySegment.local && local.isNotEmpty
          ? TextButton(
              onPressed: () => ref.read(historyProvider.notifier).clear(),
              child: const Text('\u6e05\u7a7a'),
            )
          : (_segment == HistorySegment.course && auth.isSignedIn
              ? IconButton(
                  tooltip: '\u5237\u65b0',
                  onPressed: () =>
                      ref.read(courseHistoryProvider.notifier).refresh(),
                  icon: Icon(Icons.refresh_rounded, color: p.muted),
                )
              : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.pageX,
              0,
              AppSpace.pageX,
              AppSpace.sm,
            ),
            child: SegmentedButton<HistorySegment>(
              segments: const [
                ButtonSegment(
                  value: HistorySegment.course,
                  icon: Icon(Icons.school_outlined, size: 16),
                  label: Text('\u8bfe\u7a0b\u7b7e\u5230'),
                ),
                ButtonSegment(
                  value: HistorySegment.local,
                  icon: Icon(Icons.phone_android_outlined, size: 16),
                  label: Text('\u672c\u673a\u63d0\u4ea4'),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
            ),
          ),
          Expanded(
            child: _segment == HistorySegment.course
                ? _CourseHistoryBody(signedIn: auth.isSignedIn)
                : _LocalHistoryBody(entries: local),
          ),
        ],
      ),
    );
  }
}

class _CourseHistoryBody extends ConsumerWidget {
  const _CourseHistoryBody({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    if (!signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 40, color: p.muted),
              const SizedBox(height: 12),
              Text(
                '\u767b\u5f55\u540e\u53ef\u67e5\u770b\u8bfe\u7a0b\u7b7e\u5230\u5386\u53f2',
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showLoginDialog(context),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('\u767b\u5f55'),
              ),
            ],
          ),
        ),
      );
    }

    final async = ref.watch(courseHistoryProvider);
    return RefreshIndicator(
      color: p.primary,
      onRefresh: () => ref.read(courseHistoryProvider.notifier).refresh(),
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
                    '\u62c9\u53d6\u5931\u8d25',
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
                        ref.read(courseHistoryProvider.notifier).refresh(),
                    child: const Text('\u91cd\u8bd5'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (records) {
          if (records.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 64),
                EmptyHint(
                  icon: Icons.school_outlined,
                  title: '\u6682\u65e0\u8bfe\u7a0b\u7b7e\u5230',
                  detail: '\u4e0b\u62c9\u5237\u65b0\uff0c\u6216\u786e\u8ba4\u8d26\u53f7\u5df2\u9009\u8bfe',
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
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
            itemBuilder: (context, i) => _CourseTile(record: records[i]),
          );
        },
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.record});

  final CourseRollcallRecord record;

  Color _statusColor(AppPalette p) {
    if (record.signedStatus.contains('\u5df2')) return p.primary;
    if (record.signedStatus.contains('\u672a\u7b7e')) return p.danger;
    return p.muted;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final statusColor = _statusColor(p);
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.courseTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  '${record.typeLabel} \u00b7 ${record.timeLabel}',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
                if (record.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.detail,
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xs,
              vertical: AppSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              record.signedStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalHistoryBody extends StatelessWidget {
  const _LocalHistoryBody({required this.entries});

  final List<RollcallHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (entries.isEmpty) {
      return const EmptyHint(
        icon: Icons.history,
        title: '\u5c1a\u65e0\u672c\u673a\u63d0\u4ea4',
        detail: '\u6210\u529f\u6216\u5931\u8d25\u7684\u63d0\u4ea4\u4f1a\u51fa\u73b0\u5728\u8fd9\u91cc',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.pageX,
        AppSpace.xxs,
        AppSpace.pageX,
        AppSpace.xl,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
      itemBuilder: (context, i) {
        final e = entries[i];
        return Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Icon(
                e.ok ? Icons.check_circle : Icons.cancel_outlined,
                color: e.ok ? palette.primary : palette.danger,
                size: 20,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.courseTitle.isEmpty ? '#${e.rollcallId}' : e.courseTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.typeLabel} \u00b7 ${e.at.toLocal().toString().substring(0, 19)}'
                      '${e.detail != null ? " \u00b7 ${e.detail}" : ""}',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
