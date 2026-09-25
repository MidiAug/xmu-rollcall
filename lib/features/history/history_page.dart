import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/corner_ribbon.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

enum HistorySignedFilter { all, unsigned, signed }

enum HistoryTypeFilter { all, number, radar, qr }

extension on HistorySignedFilter {
  String get label => switch (this) {
        HistorySignedFilter.all => '全部状态',
        HistorySignedFilter.unsigned => '未签到',
        HistorySignedFilter.signed => '已签到',
      };
}

extension on HistoryTypeFilter {
  String get label => switch (this) {
        HistoryTypeFilter.all => '全部类型',
        HistoryTypeFilter.number => '数字签到',
        HistoryTypeFilter.radar => '雷达签到',
        HistoryTypeFilter.qr => '二维码签到',
      };
}

/// 签到二级页：课程签到历史（不再占主 Tab）。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  HistorySignedFilter _signed = HistorySignedFilter.all;
  HistoryTypeFilter _type = HistoryTypeFilter.all;
  final _scroll = ScrollController();
  var _appeared = false;

  static const _selectW = 132.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _appeared) return;
      _appeared = true;
      if (ref.read(authControllerProvider).isSignedIn) {
        ref.read(courseHistoryProvider.notifier).ensureFresh();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageX = AppSpace.pageXOf(context);
    final auth = ref.watch(authControllerProvider);
    final localIds = {
      for (final e in ref.watch(historyProvider)) '${e.rollcallId}',
    };

    return SubpageScaffold(
      title: '签到记录',
      body: AppContentColumn(
        child: PrimaryScrollController(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pageX,
                  AppSpace.md,
                  pageX,
                  AppSpace.sm,
                ),
                child: Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppShellSelect<HistorySignedFilter>(
                      width: _selectW,
                      value: _signed,
                      items: HistorySignedFilter.values,
                      labelOf: (v) => v.label,
                      onChanged: (v) => setState(() => _signed = v),
                    ),
                    AppShellSelect<HistoryTypeFilter>(
                      width: _selectW,
                      value: _type,
                      items: HistoryTypeFilter.values,
                      labelOf: (v) => v.label,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _CourseHistoryBody(
                  signedIn: auth.isSignedIn,
                  signedFilter: _signed,
                  typeFilter: _type,
                  localRollcallIds: localIds,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseHistoryBody extends ConsumerWidget {
  const _CourseHistoryBody({
    required this.signedIn,
    required this.signedFilter,
    required this.typeFilter,
    required this.localRollcallIds,
  });

  final bool signedIn;
  final HistorySignedFilter signedFilter;
  final HistoryTypeFilter typeFilter;
  final Set<String> localRollcallIds;

  List<CourseRollcallRecord> _filter(List<CourseRollcallRecord> records) {
    return [
      for (final r in records)
        if (_matchSigned(r) && _matchType(r)) r,
    ];
  }

  bool _matchSigned(CourseRollcallRecord r) {
    if (r.isPlaceholder) {
      // Keep status rows visible under "all"; hide under signed/unsigned filters.
      return signedFilter == HistorySignedFilter.all;
    }
    switch (signedFilter) {
      case HistorySignedFilter.all:
        return true;
      case HistorySignedFilter.unsigned:
        return r.signedStatus.contains('未签');
      case HistorySignedFilter.signed:
        return r.signedStatus.contains('已');
    }
  }

  bool _matchType(CourseRollcallRecord r) {
    if (r.isPlaceholder) {
      return typeFilter == HistoryTypeFilter.all;
    }
    switch (typeFilter) {
      case HistoryTypeFilter.all:
        return true;
      case HistoryTypeFilter.number:
        return r.typeLabel.contains('数字');
      case HistoryTypeFilter.radar:
        return r.typeLabel.contains('雷达');
      case HistoryTypeFilter.qr:
        return r.typeLabel.contains('二维码') || r.typeLabel.contains('二维');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    if (!signedIn) {
      return EmptyHint(
        icon: Icons.lock_outline,
        title: '尚未登录',
        detail: '登录后可查看课程签到历史',
        action: FilledButton.icon(
          onPressed: () => showLoginDialog(context),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('登录'),
        ),
      );
    }

    final async = ref.watch(courseHistoryProvider);
    return AppPullToRefresh(
      color: p.primary,
      onRefresh: () => ref.read(courseHistoryProvider.notifier).refresh(),
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
                        ref.read(courseHistoryProvider.notifier).refresh(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (records) {
          final filtered = _filter(records);
          if (records.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(
                    icon: Icons.school_outlined,
                    title: '暂无课程签到',
                    detail: '下拉刷新，或确认账号已选课',
                  ),
                ),
              ],
            );
          }
          if (filtered.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(
                    icon: Icons.filter_alt_outlined,
                    title: '无匹配记录',
                    detail: '试试放宽状态或类型筛选',
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
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                SizedBox(height: AppSpace.stackOf(context) * 0.55),
            itemBuilder: (context, i) {
              final r = filtered[i];
              return _CourseTile(
                key: ValueKey(
                  '${r.courseId}_${r.rollcallId}_${r.signedStatus}',
                ),
                record: r,
                localMatch: localRollcallIds.contains(r.rollcallId),
              );
            },
          );
        },
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    super.key,
    required this.record,
    required this.localMatch,
  });

  final CourseRollcallRecord record;
  final bool localMatch;

  Color _statusColor(AppPalette p) {
    if (record.isPlaceholder) return p.muted;
    if (record.signedStatus.contains('已')) return p.primary;
    if (record.signedStatus.contains('未签')) return p.danger;
    return p.muted;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final statusColor = _statusColor(p);
    final title = record.courseTitle.trim().isEmpty
        ? '未命名课程'
        : record.courseTitle;
    return AppHoverSurface(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
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
                      Padding(
                        padding: EdgeInsets.only(right: localMatch ? 36 : 0),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.3,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      if (record.isPlaceholder)
                        Text(
                          '本课暂无签到记录',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        )
                      else
                        _MetaColumns(
                          type: record.typeLabel,
                          status: record.signedStatus,
                          time: record.timeLabel,
                          statusColor: statusColor,
                        ),
                      if (!record.isPlaceholder && record.detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.detail,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (localMatch) const CornerRibbon(label: '本机'),
        ],
      ),
    );
  }
}

/// Compact meta — type / status chips + time.
class _MetaColumns extends StatelessWidget {
  const _MetaColumns({
    required this.type,
    required this.status,
    required this.time,
    required this.statusColor,
  });

  final String type;
  final String status;
  final String time;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TypeChip(label: type, foreground: p.ink, background: p.surfaceHigh),
        _Chip(
          label: status,
          foreground: statusColor,
          background: statusColor.withValues(alpha: 0.12),
        ),
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.25, color: p.muted),
        ),
      ],
    );
  }
}

/// Fixed-width type chip so 二维码 / 数字 / 雷达 share one box.
/// Two-glyph labels use edge-to-edge [Row] (not letterSpacing — that leaves a
/// trailing gap and looks off-center).
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  /// Three CJK glyphs at 11sp + horizontal padding (8×2).
  static const _width = 11.0 * 3 + 16;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: foreground,
    );
    final Widget body;
    if (label.length == 2) {
      // 数····字  align with 二····码 edges inside the same content box.
      body = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label[0], style: style),
          Text(label[1], style: style),
        ],
      );
    } else {
      body = Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Container(
      width: _width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: body,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: foreground,
        ),
      ),
    );
  }
}
