import 'package:xmu_rollcall/app/app_dialogs.dart';
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

extension on _HistoryPeriod {
  String get label => switch (this) {
    _HistoryPeriod.all => '全部时间',
    _HistoryPeriod.days7 => '7天内',
    _HistoryPeriod.days30 => '30天内',
  };
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

  Future<void> _showSecondaryFilters() async {
    var type = _type;
    var period = _period;
    final identity = (
      ref.read(authControllerProvider).profile?.id,
      ref.read(selectedRollcallAccountProvider),
    );
    final result =
        await showModalBottomSheet<
          ({HistoryTypeFilter type, _HistoryPeriod period})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AppSheetFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('类型与时间', style: AppTypography.cardTitle),
                      ),
                      const AppSheetCloseButton(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '签到类型',
                            style: AppTypography.body.copyWith(
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, bounds) => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final value in HistoryTypeFilter.values)
                                  SizedBox(
                                    width: (bounds.maxWidth - 12) / 2,
                                    child: AppFilterChoice(
                                      label: value.label,
                                      selected: type == value,
                                      onTap: () => update(() => type = value),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '时间范围',
                            style: AppTypography.body.copyWith(
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, bounds) {
                              final columns =
                                  (bounds.maxWidth /
                                          (88 *
                                              MediaQuery.textScalerOf(
                                                context,
                                              ).scale(1)))
                                      .floor()
                                      .clamp(1, 3);
                              final width =
                                  (bounds.maxWidth - (columns - 1) * 12) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final value in _HistoryPeriod.values)
                                    SizedBox(
                                      width: width,
                                      child: AppFilterChoice(
                                        label: value.label,
                                        selected: period == value,
                                        onTap: () =>
                                            update(() => period = value),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: '重置',
                          kind: AppButtonKind.secondary,
                          onPressed: () => update(() {
                            type = HistoryTypeFilter.all;
                            period = _HistoryPeriod.all;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: '应用筛选',
                          onPressed: () => Navigator.pop(context, (
                            type: type,
                            period: period,
                          )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    if (!mounted ||
        result == null ||
        identity !=
            (
              ref.read(authControllerProvider).profile?.id,
              ref.read(selectedRollcallAccountProvider),
            )) {
      return;
    }
    setState(() {
      _type = result.type;
      _period = result.period;
      _range = _rangeForPeriod(_period, DateTime.now());
    });
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

    return SubpageScaffold(
      title: '签到记录',
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
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
                    final status = AppSegmentedControl<HistorySignedFilter>(
                      key: const ValueKey('history-status-filter'),
                      value: _signed,
                      trackOnTouch: true,
                      expanded: !wide,
                      onChanged: (v) => setState(() => _signed = v),
                      segments: [
                        for (final value in HistorySignedFilter.values)
                          if (value != HistorySignedFilter.other ||
                              statusCount(value) > 0 ||
                              _signed == value)
                            AppSegment(
                              value: value,
                              label: value == HistorySignedFilter.all
                                  ? '全部'
                                  : value.label,
                            ),
                      ],
                    );
                    AppToolbarChoice<String> courseChoice({
                      bool expandLabel = false,
                      double? height,
                    }) => AppToolbarChoice<String>(
                      key: const ValueKey('history-course-filter'),
                      title: '筛选课程',
                      value: courseId,
                      items: courses.keys.toList(),
                      labelOf: (id) => courses[id]!,
                      trailingOf: (id) => '(${courseCount(id)})',
                      expandLabel: expandLabel,
                      height: height,
                      onChanged: (id) => setState(() => _courseId = id),
                    );
                    if (!wide) {
                      final p = AppPalette.of(context);
                      final secondaryActive =
                          _type != HistoryTypeFilter.all ||
                          _period != _HistoryPeriod.all;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          status,
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    border: Border.all(color: p.surfaceBorder),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    boxShadow: AppGlassSurface.groupShadows(p),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    child: courseChoice(
                                      expandLabel: true,
                                      height: 44,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    boxShadow: AppGlassSurface.groupShadows(p),
                                  ),
                                  child: AppHoverSurface(
                                    key: const ValueKey(
                                      'history-secondary-filters',
                                    ),
                                    backgroundColor: secondaryActive
                                        ? p.accentSoft
                                        : p.surface,
                                    borderColor: secondaryActive
                                        ? p.accentRim
                                        : p.surfaceBorder,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    onTap: _showSecondaryFilters,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 42,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '类型与时间',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.control
                                                  .copyWith(
                                                    color: secondaryActive
                                                        ? p.primary
                                                        : p.ink,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            AppIcons.down,
                                            size: 14,
                                            color: secondaryActive
                                                ? p.primary
                                                : p.muted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    return Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        status,
                        SizedBox(
                          key: const ValueKey('history-desktop-filters'),
                          width: (408 * scale).clamp(0, bounds.maxWidth),
                          child: AppGlassSurface(
                            blur: 0,
                            opacity: 1,
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: AppToolbarChoice<HistoryTypeFilter>(
                                    key: const ValueKey('history-type-filter'),
                                    title: '签到类型',
                                    value: _type,
                                    items: HistoryTypeFilter.values,
                                    labelOf: (v) => v.label,
                                    trailingOf: (v) => '(${typeCount(v)})',
                                    onChanged: (v) => setState(() => _type = v),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: AppPalette.of(context).divider,
                                ),
                                Expanded(flex: 3, child: courseChoice()),
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: AppPalette.of(context).divider,
                                ),
                                Expanded(
                                  flex: 2,
                                  child: AppToolbarChoice<_HistoryPeriod>(
                                    key: const ValueKey('history-date-filter'),
                                    title: '时间范围',
                                    value: _period,
                                    items: _HistoryPeriod.values,
                                    labelOf: (v) => v.label,
                                    trailingOf: (v) => '(${periodCount(v)})',
                                    onChanged: _selectPeriod,
                                  ),
                                ),
                              ],
                            ),
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
                  child: EmptyHint(icon: AppIcons.homework, title: '暂无课程签到'),
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
                  child: EmptyHint(icon: AppIcons.filter, title: '无匹配记录'),
                ),
              ],
            );
          }
          final groups =
              <
                ({DateTime? day, bool placeholder}),
                List<CourseRollcallRecord>
              >{};
          for (final record in filtered) {
            final time = record.isPlaceholder
                ? null
                : record.rollcallTime?.toLocal();
            final group = (
              day: time == null ? null : DateUtils.dateOnly(time),
              placeholder: record.isPlaceholder,
            );
            groups.putIfAbsent(group, () => []).add(record);
          }
          final days = groups.entries.toList(growable: false);
          return ListView.builder(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                contentInsets +
                EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  AppSpace.xxs,
                  AppSpace.pageXOf(context),
                  AppSpace.xl,
                ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final group = days[index];
              return SettingsSection(
                header: group.key.placeholder
                    ? '暂无签到记录的课程'
                    : group.key.day == null
                    ? '时间未提供'
                    : _historyDayLabel(group.key.day!),
                headerStyle: AppTypography.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
                hasLeading: false,
                padTop: index > 0,
                children: [
                  for (var i = 0; i < group.value.length; i++)
                    _CourseTile(
                      key: ValueKey(
                        '${group.value[i].courseId}_${group.value[i].rollcallId}_${group.value[i].signedStatus}',
                      ),
                      record: group.value[i],
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

class _CourseTile extends StatelessWidget {
  const _CourseTile({super.key, required this.record});
  final CourseRollcallRecord record;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTruncatedText(
                      title,
                      style: AppTypography.body.copyWith(
                        fontSize: AppDensity.isTouch(context) ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (record.isPlaceholder)
                      Text(
                        '本课暂无签到记录',
                        style: AppTypography.caption.copyWith(
                          fontSize: AppDensity.isTouch(context) ? 13 : 12,
                          color: p.muted,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
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
                          Text(
                            record.typeLabel,
                            style: AppTypography.caption.copyWith(
                              color: p.muted,
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
              if (!record.isPlaceholder) ...[
                const SizedBox(width: 16),
                AppStatusBadge(record.signedStatus, tone: tone, pill: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
