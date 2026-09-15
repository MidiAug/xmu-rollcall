import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/corner_ribbon.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
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

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with ShellTabAware<HistoryPage> {
  HistorySignedFilter _signed = HistorySignedFilter.all;
  HistoryTypeFilter _type = HistoryTypeFilter.all;
  /// null = closed; only one menu open at a time (overlays list, does not reflow).
  _FilterKind? _openMenu;
  final _signedLink = LayerLink();
  final _typeLink = LayerLink();
  final _scroll = ScrollController();

  /// Seam between trigger bottom and menu top (not section stack gap).
  static const _menuSeam = AppSpace.xxs;

  @override
  AppDestination get shellTab => AppDestination.history;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _closeMenu() {
    if (_openMenu == null) return;
    setState(() => _openMenu = null);
  }

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _closeMenu();
  }

  @override
  void onShellTabRetap() {
    _closeMenu();
    super.onShellTabRetap();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final pageX = AppSpace.pageXOf(context);
    final auth = ref.watch(authControllerProvider);
    final localIds = {
      for (final e in ref.watch(historyProvider)) '${e.rollcallId}',
    };

    return PageScaffold(
      title: '记录',
      subtitle: '课程签到历史',
      showHeader: wide,
      trailing: auth.isSignedIn
          ? IconButton(
              tooltip: '刷新',
              onPressed: () =>
                  ref.read(courseHistoryProvider.notifier).refresh(),
              icon: Icon(Icons.refresh_rounded, color: p.muted),
            )
          : null,
      child: PrimaryScrollController(
        controller: _scroll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final triggerW =
                (constraints.maxWidth - pageX * 2 - AppSpace.xs) / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        pageX,
                        AppSpace.md,
                        pageX,
                        AppSpace.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CompositedTransformTarget(
                              link: _signedLink,
                              child: _FilterTrigger(
                                label: _signed.label,
                                open: _openMenu == _FilterKind.signed,
                                onTap: () => setState(() {
                                  _openMenu = _openMenu == _FilterKind.signed
                                      ? null
                                      : _FilterKind.signed;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: CompositedTransformTarget(
                              link: _typeLink,
                              child: _FilterTrigger(
                                label: _type.label,
                                open: _openMenu == _FilterKind.type,
                                onTap: () => setState(() {
                                  _openMenu = _openMenu == _FilterKind.type
                                      ? null
                                      : _FilterKind.type;
                                }),
                              ),
                            ),
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
                if (_openMenu != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeMenu,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  CompositedTransformFollower(
                    link: _openMenu == _FilterKind.signed
                        ? _signedLink
                        : _typeLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: const Offset(0, _menuSeam),
                    child: SizedBox(
                      width: triggerW,
                      child: _openMenu == _FilterKind.signed
                          ? _FilterPanel<HistorySignedFilter>(
                              value: _signed,
                              items: HistorySignedFilter.values,
                              labelOf: (v) => v.label,
                              onChanged: (v) => setState(() {
                                _signed = v;
                                _openMenu = null;
                              }),
                            )
                          : _FilterPanel<HistoryTypeFilter>(
                              value: _type,
                              items: HistoryTypeFilter.values,
                              labelOf: (v) => v.label,
                              onChanged: (v) => setState(() {
                                _type = v;
                                _openMenu = null;
                              }),
                            ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _FilterKind { signed, type }

class _FilterTrigger extends StatelessWidget {
  const _FilterTrigger({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
            ),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: AppMotion.duration,
              curve: AppMotion.curve,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPanel<T> extends StatelessWidget {
  const _FilterPanel({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.border),
            _FilterMenuRow(
              label: labelOf(items[i]),
              selected: items[i] == value,
              onTap: () => onChanged(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterMenuRow extends StatelessWidget {
  const _FilterMenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: selected ? p.selected : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? p.primary : p.ink,
            ),
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
      return signedFilter == HistorySignedFilter.all ||
          signedFilter == HistorySignedFilter.unsigned;
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 40, color: p.muted),
              const SizedBox(height: 12),
              Text(
                '登录后可查看课程签到历史',
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showLoginDialog(context),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('登录'),
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
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
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
    return Panel(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.sm,
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
                      Padding(
                        padding: EdgeInsets.only(right: localMatch ? 36 : 0),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
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
                        ),
                      if (!record.isPlaceholder && record.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.detail,
                          style: TextStyle(fontSize: 11, color: p.muted),
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

/// Compact fixed columns — no middot separators.
class _MetaColumns extends StatelessWidget {
  const _MetaColumns({
    required this.type,
    required this.status,
    required this.time,
  });

  final String type;
  final String status;
  final String time;

  static const _typeW = 40.0;
  static const _statusW = 44.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TextStyle(fontSize: 12, color: p.muted, height: 1.25);
    return Row(
      children: [
        SizedBox(
          width: _typeW,
          child: Text(
            type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _statusW,
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
