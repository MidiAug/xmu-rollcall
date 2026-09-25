import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

/// 我的 → 本学期课表：周×节网格（Sticky Catalog）。
class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final async = ref.watch(courseCatalogProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '课表',
      actions: [
        if (auth.isSignedIn)
          AppRefreshButton(
            onRefresh: () =>
                ref.read(courseCatalogProvider.notifier).refresh(),
          ),
      ],
      body: !auth.isSignedIn
          ? EmptyHint(
              icon: Icons.lock_outline,
              title: '尚未登录',
              detail: '登录后可查看本学期课表',
              action: FilledButton.icon(
                onPressed: () => showLoginDialog(context),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('登录'),
              ),
            )
          : async.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppPullToRefresh(
                color: p.primary,
                onRefresh: () =>
                    ref.read(courseCatalogProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '暂时无法更新课表',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('$e', style: TextStyle(color: p.muted)),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref
                                .read(courseCatalogProvider.notifier)
                                .refresh(),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              data: (snap) => _TimetableBody(snap: snap),
            ),
    );
  }
}

class _TimetableBody extends StatelessWidget {
  const _TimetableBody({required this.snap});

  final CourseCatalogSnapshot? snap;

  @override
  Widget build(BuildContext context) {
    final courses = snap?.courses ?? const <CatalogCourse>[];
    final withSlots =
        courses.where((c) => c.timetables.isNotEmpty).toList(growable: false);
    if (withSlots.isEmpty) {
      return const EmptyHint(
        icon: Icons.calendar_view_week_outlined,
        title: '暂无课表安排',
        detail: '点右上角刷新，或确认账号本学期已有排课',
      );
    }

    final fetched = snap?.fetchedAt;
    final meta = fetched == null
        ? null
        : '更新于 ${fetched.toLocal().toString().substring(0, 16)}';
    final p = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                meta,
                style: TextStyle(fontSize: 11, color: p.muted),
              ),
            ),
          Expanded(
            child: _TimetableGrid(courses: withSlots),
          ),
        ],
      ),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({required this.courses});

  final List<CatalogCourse> courses;

  static const _headerH = 32.0;
  static const _periodColW = 40.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final days = visibleWeekdays(courses);
    final rows = buildTimetableAxisRows(courses);
    final seqIndex = sequenceToRowIndex(rows);
    final blocks = placeTimetableBlocks(courses);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }

        final breakCount = rows.where((r) => r.isBreak).length;
        final periodCount = rows.length - breakCount;
        final bodyH = (h - _headerH).clamp(1.0, h);
        // Breaks take ~42% of a period row; distribute remaining to periods.
        final breakH = periodCount == 0
            ? 0.0
            : (bodyH / (periodCount + breakCount * 0.42) * 0.42)
                .clamp(12.0, 20.0);
        final periodH = periodCount == 0
            ? bodyH
            : ((bodyH - breakH * breakCount) / periodCount).clamp(18.0, 80.0);
        final dayW = (w - _periodColW) / days.length;
        final usedBodyH = periodH * periodCount + breakH * breakCount;

        double yOfRow(int rowIndex) {
          var y = 0.0;
          for (var i = 0; i < rowIndex; i++) {
            y += rows[i].isBreak ? breakH : periodH;
          }
          return y;
        }

        final blockWidgets = <Widget>[];
        for (final b in blocks) {
          if (!days.contains(b.weekday)) continue;
          final startRow = seqIndex[b.block.startSequence];
          final endRow = seqIndex[b.block.endSequence];
          if (startRow == null || endRow == null) continue;
          final dayIdx = days.indexOf(b.weekday);
          final top = yOfRow(startRow) + 1;
          final bottom = yOfRow(endRow) +
              (rows[endRow].isBreak ? breakH : periodH) -
              1;
          blockWidgets.add(
            Positioned(
              left: dayIdx * dayW + 1.5,
              width: dayW - 3,
              top: top,
              height: (bottom - top).clamp(16.0, usedBodyH),
              child: _CourseBlockChip(
                block: b,
                color: timetableColorForCourseId(b.course.id),
                onTap: () => _showBlockDetail(context, b),
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: _headerH,
              child: Row(
                children: [
                  const SizedBox(width: _periodColW),
                  for (final d in days)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdayLabel(d),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (d == 6 || d == 7) ? p.primary : p.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: usedBodyH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _periodColW,
                    height: usedBodyH,
                    child: Column(
                      children: [
                        for (final r in rows)
                          _axisLabel(r, p, periodH: periodH, breakH: breakH),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: usedBodyH,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              for (final r in rows)
                                Container(
                                  height: r.isBreak ? breakH : periodH,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: r.isBreak
                                        ? p.surfaceHigh.withValues(alpha: 0.5)
                                        : null,
                                    border: Border(
                                      top: BorderSide(
                                        color: p.border,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: r.isBreak
                                      ? Text(
                                          r.breakLabel ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: p.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      : null,
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Expanded(
                                  child: Container(
                                    height: usedBodyH,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: p.border,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          ...blockWidgets,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _axisLabel(
    TimetableAxisRow r,
    AppPalette p, {
    required double periodH,
    required double breakH,
  }) {
    if (r.isBreak) return SizedBox(height: breakH);
    return SizedBox(
      height: periodH,
      width: _periodColW,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${r.sequence}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: p.ink,
            ),
          ),
          if (r.start != null && r.end != null && periodH >= 28)
            Text(
              '${formatHm(r.start!)}\n${formatHm(r.end!)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                height: 1.1,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }

  void _showBlockDetail(BuildContext context, TimetablePlacedBlock b) {
    final p = AppPalette.of(context);
    final c = b.course;
    final color = timetableColorForCourseId(c.id);
    final title = timetableCourseTitle(c);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppRadii.dialog),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: color),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.schedule_outlined,
                          text:
                              '${weekdayLabel(b.weekday)} ${b.block.sectionLabel}'
                              '（${formatHm(b.block.coreStart)}-${formatHm(b.block.coreEnd)}）',
                          muted: p.muted,
                          ink: p.ink,
                        ),
                        if (c.instructorsLabel.isNotEmpty)
                          _DetailRow(
                            icon: Icons.person_outline,
                            text: c.instructorsLabel,
                            muted: p.muted,
                            ink: p.ink,
                          ),
                        if (c.location != null && c.location!.isNotEmpty)
                          _DetailRow(
                            icon: Icons.place_outlined,
                            text: c.location!,
                            muted: p.muted,
                            ink: p.ink,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    required this.muted,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBlockChip extends StatelessWidget {
  const _CourseBlockChip({
    required this.block,
    required this.color,
    required this.onTap,
  });

  final TimetablePlacedBlock block;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = block.course;
    final onBlock = _onColor(color);
    final title = timetableCourseTitle(c);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: onBlock,
                  ),
                ),
              ),
              if (c.location != null && c.location!.isNotEmpty)
                Text(
                  '@${c.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.1,
                    color: onBlock.withValues(alpha: 0.85),
                  ),
                ),
              if (c.instructorNames.isNotEmpty)
                Text(
                  c.instructorNames.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.1,
                    color: onBlock.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _onColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.45
        ? const Color(0xFF18181B)
        : const Color(0xFFF8F8FA);
  }
}
