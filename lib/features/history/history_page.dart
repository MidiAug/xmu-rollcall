import 'dart:async';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/history/history_summary.dart';

// Counts for filters retain their original scoped deduplication; only the
// full-history view needs ordering, and it changes with the source snapshot.
final _orderedHistoryProvider =
    Provider.autoDispose<List<CourseRollcallRecord>>((ref) {
      final records = ref.watch(
        currentCourseHistoryProvider.select((s) => s.valueOrNull),
      );
      return HistorySummary(records ?? const []).records;
    });

enum HistorySignedFilter { all, unsigned, signed, other }

enum _HistoryPeriod { all, days7, days30 }

DateTimeRange? _rangeForPeriod(_HistoryPeriod period, DateTime now) {
  final days = switch (period) {
    _HistoryPeriod.all => null,
    _HistoryPeriod.days7 => 7,
    _HistoryPeriod.days30 => 30,
  };
  return days == null
      ? null
      : DateTimeRange(
          start: DateTime(now.year, now.month, now.day - days + 1),
          end: now,
        );
}

enum HistoryTypeFilter { all, number, radar, qr }

extension on HistorySignedFilter {
  String get label => switch (this) {
    HistorySignedFilter.all => '全部状态',
    HistorySignedFilter.unsigned => '未签到',
    HistorySignedFilter.signed => '已签到',
    HistorySignedFilter.other => '其他状态',
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

class _HistoryPageState extends ConsumerState<HistoryPage>
    with WidgetsBindingObserver {
  HistorySignedFilter _signed = HistorySignedFilter.all;
  HistoryTypeFilter _type = HistoryTypeFilter.all;
  String _courseId = '';
  _HistoryPeriod _period = _HistoryPeriod.all;
  DateTimeRange? _range;
  final _scroll = ScrollController();
  Timer? _refreshTimer;

  void _selectPeriod(_HistoryPeriod period) {
    setState(() {
      _period = period;
      _range = _rangeForPeriod(period, DateTime.now());
    });
  }

  void _resetFilters() {
    _courseId = '';
    _signed = HistorySignedFilter.all;
    _type = HistoryTypeFilter.all;
    _period = _HistoryPeriod.all;
    _range = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncRefreshTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisible());
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _syncRefreshTimer();
  }

  void _refreshVisible() {
    if (!mounted ||
        !TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        !ref.read(authControllerProvider).isSignedIn) {
      return;
    }
    // The provider retains load errors for the existing retry UI.
    unawaited(
      ref
          .read(currentHistoryControllerProvider)
          .ensureFresh()
          .catchError((Object _) {}),
    );
  }

  void _syncRefreshTimer([AppLifecycleState? state]) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final lifecycle = state ?? WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      _refreshTimer = Timer.periodic(
        CachePolicy.activeClassHistoryFreshFor,
        (_) => _refreshVisible(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncRefreshTimer(state);
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisible());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageX = AppSpace.pageXOf(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider.select((s) => s.profile?.id), (
      before,
      after,
    ) {
      if (before != after) setState(_resetFilters);
    });
    ref.listen(selectedRollcallAccountProvider, (before, after) {
      if (before != after) setState(_resetFilters);
    });
    final records = auth.isSignedIn
        ? ref.watch(currentCourseHistoryProvider).valueOrNull ??
              const <CourseRollcallRecord>[]
        : const <CourseRollcallRecord>[];
    final courses = <String, String>{'': '全部课程'};
    for (final record in records) {
      if (record.courseId.isNotEmpty) {
        courses.putIfAbsent(
          record.courseId,
          () =>
              record.courseTitle.trim().isEmpty ? '未命名课程' : record.courseTitle,
        );
      }
    }
    final courseId = courses.containsKey(_courseId) ? _courseId : '';
    final summary = HistorySummary(
      records.where(
        (r) =>
            (courseId.isEmpty || r.courseId == courseId) &&
            _historyMatchesType(r, _type) &&
            historyInDateRange(r, _range?.start, _range?.end),
      ),
      sort: false,
    );
    final datedRecords = HistorySummary(
      records.where((r) => historyInDateRange(r, _range?.start, _range?.end)),
      sort: false,
    ).records;
    int typeCount(HistoryTypeFilter type) => datedRecords
        .where(
          (r) =>
              (courseId.isEmpty || r.courseId == courseId) &&
              _historyMatchesStatus(r, _signed) &&
              _historyMatchesType(r, type),
        )
        .length;
    final courseCounts = <String, int>{};
    var allCoursesCount = 0;
    for (final record in datedRecords) {
      if (!_historyMatchesStatus(record, _signed) ||
          !_historyMatchesType(record, _type)) {
        continue;
      }
      allCoursesCount++;
      courseCounts.update(
        record.courseId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    int courseCount(String id) =>
        id.isEmpty ? allCoursesCount : courseCounts[id] ?? 0;
    int statusCount(HistorySignedFilter status) => switch (status) {
      HistorySignedFilter.all => summary.total,
      HistorySignedFilter.signed => summary.count(HistoryAttendance.signed),
      HistorySignedFilter.unsigned => summary.count(HistoryAttendance.unsigned),
      HistorySignedFilter.other => summary.count(HistoryAttendance.other),
    };
    final periodRecords =
        (auth.isSignedIn
                ? ref.watch(_orderedHistoryProvider)
                : const <CourseRollcallRecord>[])
            .where(
              (r) =>
                  (courseId.isEmpty || r.courseId == courseId) &&
                  _historyMatchesStatus(r, _signed) &&
                  _historyMatchesType(r, _type),
            )
            .toList();
    final now = DateTime.now();
    int periodCount(_HistoryPeriod period) {
      final range = _rangeForPeriod(period, now);
      return periodRecords
          .where((r) => historyInDateRange(r, range?.start, range?.end))
          .length;
    }

    final labels = [
      ...HistorySignedFilter.values.map((value) => value.label),
      ...HistoryTypeFilter.values.map((value) => value.label),
      '全部课程',
      if (wide && auth.isSignedIn) '全部时间',
    ];
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 0.0;
    for (final label in labels) {
      painter.text = TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
      painter.layout();
      if (painter.width > labelWidth) {
        labelWidth = painter.width;
      }
    }
    painter.dispose();

    return SubpageScaffold(
      title: '签到记录',
      actions: [
        if (auth.isSignedIn && !wide)
          _HistoryDateFilter(
            value: _period,
            onSelected: _selectPeriod,
            countOf: periodCount,
          ),
      ],
      body: AppPageViewport(
        builder: (context, contentInsets) => PrimaryScrollController(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    contentInsets +
                    EdgeInsets.fromLTRB(pageX, AppSpace.sm, pageX, AppSpace.xs),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    // Leave room for trigger insets and its disclosure. Long
                    // selected course names still use their truncated tooltip.
                    final count = wide && auth.isSignedIn ? 4 : 3;
                    final columns =
                        ((bounds.maxWidth + AppSpace.xs) /
                                (labelWidth.ceilToDouble() + 40 + AppSpace.xs))
                            .floor()
                            .clamp(1, count);
                    final fieldWidth =
                        (bounds.maxWidth - (columns - 1) * AppSpace.xs) /
                        columns;
                    return Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _HistoryFilter<HistorySignedFilter>(
                            title: '签到状态',
                            key: const ValueKey('history-status-filter'),
                            value: _signed,
                            items: HistorySignedFilter.values,
                            labelOf: (v) => v.label,
                            countOf: statusCount,
                            onChanged: (v) => setState(() => _signed = v),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _HistoryFilter<HistoryTypeFilter>(
                            title: '签到类型',
                            key: const ValueKey('history-type-filter'),
                            value: _type,
                            items: HistoryTypeFilter.values,
                            labelOf: (v) => v.label,
                            countOf: typeCount,
                            onChanged: (v) => setState(() => _type = v),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _HistoryFilter<String>(
                            title: '筛选课程',
                            key: const ValueKey('history-course-filter'),
                            value: courseId,
                            items: courses.keys.toList(),
                            labelOf: (id) => courses[id]!,
                            countOf: courseCount,
                            wideMenu: true,
                            onChanged: (id) => setState(() => _courseId = id),
                          ),
                        ),
                        if (wide && auth.isSignedIn)
                          SizedBox(
                            width: fieldWidth,
                            child: _HistoryDateFilter(
                              value: _period,
                              onSelected: _selectPeriod,
                              countOf: periodCount,
                              expand: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: _CourseHistoryBody(
                  contentInsets: contentInsets,
                  signedIn: auth.isSignedIn,
                  signedFilter: _signed,
                  typeFilter: _type,
                  courseId: courseId,
                  start: _range?.start,
                  end: _range?.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width compact triggers; menu labels can wrap independently of the row.
class _HistoryFilter<T> extends StatelessWidget {
  const _HistoryFilter({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.countOf,
    required this.onChanged,
    this.wideMenu = false,
  });
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final int Function(T) countOf;
  final ValueChanged<T> onChanged;
  final bool wideMenu;
  final String title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) => AppShellSelect<T>(
        semanticLabel: title,
        value: value,
        items: items,
        labelOf: labelOf,
        menuTrailingOf: (v) => '(${countOf(v)})',
        onChanged: onChanged,
        width: bounds.maxWidth,
        menuWidth: wideMenu ? 240 : 160,
      ),
    );
  }
}

class _CourseHistoryBody extends ConsumerWidget {
  const _CourseHistoryBody({
    required this.signedIn,
    this.contentInsets = EdgeInsets.zero,
    required this.signedFilter,
    required this.typeFilter,
    required this.courseId,
    this.start,
    this.end,
  });

  final bool signedIn;
  final EdgeInsets contentInsets;
  final HistorySignedFilter signedFilter;
  final HistoryTypeFilter typeFilter;
  final String courseId;
  final DateTime? start, end;

  List<CourseRollcallRecord> _filter(List<CourseRollcallRecord> records) {
    return [
      for (final r in records)
        if ((courseId.isEmpty || r.courseId == courseId) &&
            _matchSigned(r) &&
            _historyMatchesType(r, typeFilter) &&
            historyInDateRange(r, start, end))
          r,
    ];
  }

  bool _matchSigned(CourseRollcallRecord r) =>
      _historyMatchesStatus(r, signedFilter);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    if (!signedIn) {
      return EmptyHint(
        icon: AppIcons.lock,
        title: '尚未登录',
        detail: '登录后可查看课程签到历史',
        action: FilledButton.icon(
          onPressed: () => showLoginDialog(context),
          icon: const Icon(AppIcons.login, size: 18),
          label: const Text('登录'),
        ),
      );
    }

    final async = ref.watch(currentCourseHistoryProvider);
    return AppPullToRefresh(
      color: p.primary,
      onRefresh: () => ref
          .read(currentHistoryControllerProvider)
          .refresh(courseId: courseId.isEmpty ? null : courseId),
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentInsets + const EdgeInsets.all(24),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拉取失败',
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text('$e', style: TextStyle(color: p.muted)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref
                        .read(currentHistoryControllerProvider)
                        .refresh(courseId: courseId.isEmpty ? null : courseId),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (records) {
          // Counts and rows describe the same course/rollcall observations in
          // the current identity. Keep empty-course placeholders separate.
          final filtered = _filter([
            ...ref.watch(_orderedHistoryProvider),
            ...records.where((record) => record.isPlaceholder),
          ]);
          if (records.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(
                    icon: AppIcons.homework,
                    title: '暂无课程签到',
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
                    icon: AppIcons.filter,
                    title: '无匹配记录',
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                contentInsets +
                EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  AppSpace.xxs,
                  AppSpace.pageXOf(context),
                  AppSpace.xl,
                ),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox.shrink(),
            itemBuilder: (context, i) {
              final r = filtered[i];
              final date = r.isPlaceholder ? null : r.rollcallTime?.toLocal();
              final previous = i == 0 || filtered[i - 1].isPlaceholder
                  ? null
                  : filtered[i - 1].rollcallTime?.toLocal();
              final startsPlaceholders =
                  r.isPlaceholder && (i == 0 || !filtered[i - 1].isPlaceholder);
              final startsUndated =
                  !r.isPlaceholder &&
                  date == null &&
                  (i == 0 ||
                      filtered[i - 1].isPlaceholder ||
                      filtered[i - 1].rollcallTime != null);
              final startsDay =
                  date != null &&
                  (previous == null ||
                      DateUtils.dateOnly(date) != DateUtils.dateOnly(previous));
              final next = i + 1 < filtered.length ? filtered[i + 1] : null;
              final endsGroup =
                  next == null ||
                  r.isPlaceholder != next.isPlaceholder ||
                  (!r.isPlaceholder &&
                      (date == null
                          ? next.rollcallTime != null
                          : next.rollcallTime == null ||
                                DateUtils.dateOnly(date) !=
                                    DateUtils.dateOnly(
                                      next.rollcallTime!.toLocal(),
                                    )));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (startsDay || startsPlaceholders || startsUndated)
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 8),
                      child: Text(
                        startsPlaceholders
                            ? '暂无签到记录的课程'
                            : startsUndated
                            ? '时间未提供'
                            : _historyDayLabel(date!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: p.muted,
                        ),
                      ),
                    ),
                  _CourseTile(
                    key: ValueKey(
                      '${r.courseId}_${r.rollcallId}_${r.signedStatus}',
                    ),
                    record: r,
                    first: startsDay || startsPlaceholders || startsUndated,
                    last: endsGroup,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

bool _historyMatchesType(CourseRollcallRecord r, HistoryTypeFilter typeFilter) {
  if (r.isPlaceholder) return typeFilter == HistoryTypeFilter.all;
  return switch (typeFilter) {
    HistoryTypeFilter.all => true,
    HistoryTypeFilter.number => r.typeLabel.contains('数字'),
    HistoryTypeFilter.radar => r.typeLabel.contains('雷达'),
    HistoryTypeFilter.qr =>
      r.typeLabel.contains('二维码') || r.typeLabel.contains('二维'),
  };
}

String _historyDayLabel(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final year = date.year == DateTime.now().year ? '' : '${date.year}年';
  return '$year${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

bool _historyMatchesStatus(
  CourseRollcallRecord record,
  HistorySignedFilter filter,
) {
  if (record.isPlaceholder) return filter == HistorySignedFilter.all;
  return switch (filter) {
    HistorySignedFilter.all => true,
    HistorySignedFilter.signed =>
      historyAttendance(record) == HistoryAttendance.signed,
    HistorySignedFilter.unsigned =>
      historyAttendance(record) == HistoryAttendance.unsigned,
    HistorySignedFilter.other =>
      historyAttendance(record) == HistoryAttendance.other,
  };
}

class _HistoryDateFilter extends StatelessWidget {
  const _HistoryDateFilter({
    required this.value,
    required this.onSelected,
    required this.countOf,
    this.expand = false,
  });
  final _HistoryPeriod value;
  final ValueChanged<_HistoryPeriod> onSelected;
  final int Function(_HistoryPeriod) countOf;
  final bool expand;
  static const labels = {
    _HistoryPeriod.all: '全部时间',
    _HistoryPeriod.days7: '7天内',
    _HistoryPeriod.days30: '30天内',
  };
  @override
  Widget build(BuildContext context) {
    if (expand) {
      return _HistoryFilter<_HistoryPeriod>(
        title: '时间范围',
        key: const ValueKey('history-date-filter'),
        value: value,
        items: _HistoryPeriod.values,
        labelOf: (v) => labels[v]!,
        countOf: countOf,
        onChanged: onSelected,
      );
    }
    if (AppMobileUi.useTouchChrome(context)) {
      return AppToolbarChoice<_HistoryPeriod>(
        key: const ValueKey('history-date-filter'),
        title: '时间范围',
        value: value,
        items: _HistoryPeriod.values,
        labelOf: (v) => labels[v]!,
        trailingOf: (v) => '(${countOf(v)})',
        onChanged: onSelected,
      );
    }
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 0.0;
    for (final label in labels.values) {
      painter.text = TextSpan(
        text: label,
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      );
      painter.layout();
      if (painter.width > labelWidth) labelWidth = painter.width;
    }
    painter.dispose();
    // Include padding, the arrow and spacing, with room for the full label.
    final width = labelWidth + 64;
    return Center(
      child: AppShellSelect<_HistoryPeriod>(
        key: const ValueKey('history-date-filter'),
        value: value,
        items: _HistoryPeriod.values,
        labelOf: (v) => labels[v]!,
        menuTrailingOf: (v) => '(${countOf(v)})',
        onChanged: onSelected,
        width: width,
        menuWidth: width + 64,
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    super.key,
    required this.record,
    required this.first,
    required this.last,
  });
  final CourseRollcallRecord record;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = record.courseTitle.trim().isEmpty
        ? '未命名课程'
        : record.courseTitle;
    final time = record.rollcallTime?.toLocal();
    final tone = switch (historyAttendance(record)) {
      HistoryAttendance.signed => AppStatusTone.success,
      HistoryAttendance.unsigned => AppStatusTone.danger,
      HistoryAttendance.other => AppStatusTone.neutral,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(AppRadii.group) : Radius.zero,
          bottom: last ? const Radius.circular(AppRadii.group) : Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (record.isPlaceholder)
                  Text(
                    '本课暂无签到记录',
                    style: AppTypography.caption.copyWith(color: p.muted),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(record.signedStatus, tone: tone),
                      Text(
                        record.typeLabel,
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                      if (time != null)
                        Tooltip(
                          message: record.timeLabel,
                          child: Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            style: AppTypography.caption.copyWith(
                              color: p.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                if (!record.isPlaceholder && record.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.detail,
                    style: AppTypography.caption.copyWith(
                      color: p.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!last)
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: p.border,
            ),
        ],
      ),
    );
  }
}
