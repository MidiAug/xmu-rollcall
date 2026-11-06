import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'grade_models.dart';
import 'grade_providers.dart';

class GpaPage extends ConsumerStatefulWidget {
  const GpaPage({super.key});
  @override
  ConsumerState<GpaPage> createState() => _GpaPageState();
}

class _GpaPageState extends ConsumerState<GpaPage> {
  final _excluded = <String>{};
  int? _uid;
  String? _term, _error;
  GradeRange _range = GradeRange.all;
  final _years = <int>{};
  int _recentCount = 2;
  bool _excludeGeneral = false;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final uid = ref.watch(selectedRollcallAccountProvider) ?? auth.profile?.id;
    if (_uid != uid) {
      _uid = uid;
      _term = null;
      _years.clear();
      _range = GradeRange.all;
      _recentCount = 2;
      _excludeGeneral = false;
      _error = null;
      _excluded.clear();
    }
    final data = auth.isSignedIn ? ref.watch(gradeSnapshotProvider) : null;
    return SubpageScaffold(
      title: 'GPA 计算器',
      actions: [
        if (auth.isSignedIn)
          AppRefreshButton(
            tooltip: '更新成绩',
            onRefresh: () async {
              setState(() => _error = null);
              try {
                await ref.read(gradeSnapshotProvider.notifier).refresh();
              } catch (_) {
                if (mounted &&
                    (ref.read(selectedRollcallAccountProvider) ??
                            ref.read(authControllerProvider).profile?.id) ==
                        uid) {
                  setState(() => _error = '更新失败，请稍后重试；已有成绩仍保留');
                }
              }
            },
          ),
      ],
      body: !auth.isSignedIn
          ? const EmptyHint(
              icon: AppIcons.person,
              title: '请先登录',
              detail: '成绩使用当前选中账号的教务会话',
            )
          : data!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyHint(
                icon: AppIcons.document,
                title: '暂时无法读取成绩',
                detail: error is FormatException
                    ? error.message
                    : '请稍后重试，或重新登录当前账号以连接教务',
                action: FilledButton(
                  onPressed: () => ref.invalidate(gradeSnapshotProvider),
                  child: const Text('重试'),
                ),
              ),
              data: (snapshot) {
                final terms = gradeTerms(snapshot.records);
                final years = gradeYears(snapshot.records);
                final selectedYears = _years.intersection(years.toSet());
                final effectiveTerm = terms.contains(_term)
                    ? _term
                    : terms.firstOrNull;
                final recentCount = terms.isEmpty
                    ? 1
                    : _recentCount.clamp(1, terms.length);
                final visible = selectGradeRange(
                  snapshot.records,
                  range: _range,
                  years: selectedYears,
                  term: effectiveTerm,
                  recentCount: recentCount,
                );
                final scopeLabel = switch (_range) {
                  GradeRange.all => '全部成绩',
                  GradeRange.year =>
                    selectedYears.isEmpty
                        ? '请选择学年'
                        : (selectedYears.toList()..sort())
                              .map((y) => '$y—${y + 1}学年')
                              .join('、'),
                  GradeRange.recent => '最近 $recentCount 个有成绩的学期',
                  GradeRange.term =>
                    effectiveTerm == null ? '暂无学期' : _termLabel(effectiveTerm),
                };
                final included = visible
                    .where(
                      (r) =>
                          r.eligible &&
                          !_excluded.contains(r.id) &&
                          !(_excludeGeneral && r.generalEducation),
                    )
                    .toList();
                final summary = calculateGpa(included);
                return AppPageViewport(
                  maxWidth: 960,
                  builder: (context, contentInsets) => ListView(
                    padding:
                        contentInsets +
                        EdgeInsets.fromLTRB(
                          AppSpace.pageXOf(context),
                          12,
                          AppSpace.pageXOf(context),
                          24,
                        ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, bounds) {
                                final segments =
                                    AppSegmentedControl<GradeRange>(
                                      key: const ValueKey('grade-range'),
                                      expanded: true,
                                      value: _range,
                                      segments: const [
                                        AppSegment(
                                          value: GradeRange.all,
                                          label: '总绩点',
                                        ),
                                        AppSegment(
                                          value: GradeRange.year,
                                          label: '学年',
                                        ),
                                        AppSegment(
                                          value: GradeRange.recent,
                                          label: '近学期',
                                        ),
                                        AppSegment(
                                          value: GradeRange.term,
                                          label: '学期',
                                        ),
                                      ],
                                      onChanged: (r) => setState(() {
                                        _range = r;
                                        if (r == GradeRange.year &&
                                            selectedYears.isEmpty &&
                                            years.isNotEmpty) {
                                          _years.add(years.first);
                                        }
                                      }),
                                    );
                                final general = SizedBox(
                                  width: 172,
                                  child: AppCheckboxRow(
                                    label: '排除通识课程',
                                    value: _excludeGeneral,
                                    onChanged: (v) =>
                                        setState(() => _excludeGeneral = v),
                                  ),
                                );
                                return bounds.maxWidth >= 600
                                    ? Row(
                                        children: [
                                          SizedBox(width: 340, child: segments),
                                          const Spacer(),
                                          general,
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          segments,
                                          const SizedBox(height: 8),
                                          general,
                                        ],
                                      );
                              },
                            ),
                            if (_range == GradeRange.year) ...[
                              const SizedBox(height: 12),
                              Text(
                                '选择实际学年，可多选',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  for (final y in years)
                                    FilterChip(
                                      key: ValueKey('grade-year-$y'),
                                      label: Text('$y—${y + 1}学年'),
                                      labelStyle: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      selected: selectedYears.contains(y),
                                      onSelected: (v) => setState(
                                        () => v
                                            ? _years.add(y)
                                            : _years.remove(y),
                                      ),
                                    ),
                                  if (years.isEmpty)
                                    Text(
                                      snapshot.records.isEmpty
                                          ? '成绩发布后显示可选学年'
                                          : '暂无可识别的学年',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ],
                            if (_range == GradeRange.recent &&
                                terms.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              AppShellSelect<int>(
                                key: const ValueKey('grade-recent'),
                                semanticLabel: '最近学期数量',
                                width: 164,
                                value: recentCount,
                                items: [
                                  for (var n = 1; n <= terms.length; n++) n,
                                ],
                                labelOf: (n) => '近 $n 个学期',
                                onChanged: (n) =>
                                    setState(() => _recentCount = n),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '按有成绩的学期倒序选取，含夏季及短学期',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (_range == GradeRange.term &&
                                effectiveTerm != null) ...[
                              const SizedBox(height: 12),
                              AppShellSelect<String>(
                                key: const ValueKey('grade-term'),
                                semanticLabel: '选择学期',
                                width: 210,
                                value: effectiveTerm,
                                items: terms,
                                labelOf: _termLabel,
                                onChanged: (t) => setState(() => _term = t),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _summaryPanel(
                        context,
                        summary,
                        scopeLabel,
                        visible,
                        included,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '更新于 ${snapshot.at.toLocal().toString().substring(0, 16)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_error != null ||
                          ref.read(gradeSnapshotProvider.notifier).warning !=
                              null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error ??
                              ref.read(gradeSnapshotProvider.notifier).warning!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: p.danger),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            '课程明细',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '已选 ${included.length} 门 / 可计 ${visible.where((r) => r.eligible).length} 门',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_excluded.isNotEmpty || _excludeGeneral)
                            AppTextLink(
                              '恢复默认选择',
                              onPressed: () => setState(() {
                                _excluded.clear();
                                _excludeGeneral = false;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              snapshot.records.isEmpty
                                  ? snapshot.education == 'graduate'
                                        ? '教务查询成功，暂未发布成绩；出分后可手动刷新'
                                        : '暂无已公布成绩'
                                  : _range == GradeRange.year &&
                                        selectedYears.isEmpty
                                  ? '选择学年后查看课程与 GPA'
                                  : '当前范围暂无成绩',
                              style: TextStyle(color: p.muted),
                            ),
                          ),
                        )
                      else
                        for (final term in [
                          ...gradeTerms(visible),
                          if (visible.any((r) => r.term.isEmpty)) '',
                        ]) ...[
                          const SizedBox(height: 12),
                          Panel(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _termLabel(term),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: p.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'GPA ${calculateGpa(included.where((r) => r.term == term)).gpa?.toStringAsFixed(2) ?? '—'}',
                                            style: TextStyle(
                                              color: p.dataAccent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${visible.where((r) => r.term == term).length} 门',
                                            style: TextStyle(
                                              color: p.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                for (final (index, row)
                                    in visible
                                        .where((r) => r.term == term)
                                        .indexed) ...[
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      indent: 60,
                                      endIndent: 16,
                                      color: p.border,
                                    ),
                                  _GradeCourseRow(
                                    key: ValueKey('grade-${row.id}'),
                                    row: row,
                                    selected:
                                        row.eligible &&
                                        !_excluded.contains(row.id) &&
                                        !(_excludeGeneral &&
                                            row.generalEducation),
                                    excludedGeneral:
                                        row.eligible &&
                                        _excludeGeneral &&
                                        row.generalEducation,
                                    onChanged:
                                        row.eligible &&
                                            !(_excludeGeneral &&
                                                row.generalEducation)
                                        ? (value) => setState(
                                            () => value
                                                ? _excluded.remove(row.id)
                                                : _excluded.add(row.id),
                                          )
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      const SizedBox(height: 16),
                      Text(
                        '两级制及 N/A 不计入；0 绩点和每次修读成绩按教务规则计入。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _rules(
                        context,
                        graduate: snapshot.education == 'graduate',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _summaryPanel(
    BuildContext context,
    ({double credits, double? gpa, double? average}) summary,
    String scope,
    List<GradeRecord> visible,
    List<GradeRecord> included,
  ) {
    final p = AppPalette.of(context);
    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scope, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        AppMetric(
          value: summary.gpa?.toStringAsFixed(2) ?? '—',
          label: '加权 GPA',
          valueSize: 56,
          valueColor: p.dataAccent,
        ),
      ],
    );
    final secondary = Row(
      children: [
        Expanded(
          child: AppMetric(
            label: '加权均分',
            value: summary.average?.toStringAsFixed(2) ?? '—',
          ),
        ),
        Expanded(
          child: AppMetric(
            label: '计入学分',
            value: summary.credits.toStringAsFixed(1),
          ),
        ),
      ],
    );
    return Panel(
      key: const ValueKey('grade-summary'),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth >= 560
            ? Row(
                children: [
                  Expanded(flex: 3, child: primary),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        secondary,
                        if (gradeTerms(
                              visible,
                            ).where((t) => GradeTerm.parse(t) != null).length >
                            1) ...[
                          const SizedBox(height: 24),
                          _SemesterGpaChart(
                            visible: visible,
                            included: included,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primary,
                  const SizedBox(height: 20),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 20),
                  secondary,
                ],
              ),
      ),
    );
  }

  Widget _rules(BuildContext context, {bool graduate = false}) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          '计算规则与来源',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            graduate
                ? '研究生成绩使用独立教务应用，GPA 按教务返回的绩点值（JDZ）与学分加权；不使用本科分数或字母等级换算表。缺少有效绩点的课程不计入 GPA。\n刚入学、成绩尚未发布时，成功查询可以返回空列表，出分后可手动刷新。当前结果是本机试算，正式成绩及认定以研究生教务为准。'
                : '依据厦大教〔2022〕8号本科生成绩管理办法：GPA = Σ（课程绩点 × 学分）÷ Σ计入学分。优先使用教务绩点，荣誉课程保留教务值，不自行用分数推算。每次修读均计入，不只取最高分。\n'
                      '两级制 P/NP、免修 EX、缓考 DF、退课 W 和教务标记 N/A 不计入；百分制或等级制的 F/0 绩点计入。\n'
                      '通识课程不按名称一概排除：有有效教务绩点时默认计入，N/A 自动排除；未获认定的任意选修课不计入。学院评奖等另有口径时，可用“排除通识课程”或逐门勾选调整。\n'
                      '加权均分使用数值成绩；字母等级按校方表2的对应分数计算。当前结果为本机试算，正式排名以教务及学院认定为准。',
            style: TextStyle(fontSize: 12, color: p.muted, height: 1.7),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (graduate)
                AppTextLink(
                  '研究生成绩管理文件',
                  onPressed: () => launchUrl(
                    Uri.parse('https://med.xmu.edu.cn/info/1167/5734.htm'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              if (!graduate)
                AppTextLink(
                  '本科生成绩管理办法',
                  onPressed: () => launchUrl(
                    Uri.parse('https://gk.xmu.edu.cn/info/1065/25331.htm'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              if (!graduate)
                AppTextLink(
                  '学分认定与转换办法',
                  onPressed: () => launchUrl(
                    Uri.parse('https://life.xmu.edu.cn/info/1058/1030.htm'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _termLabel(String term) =>
      GradeTerm.parse(term)?.label ?? (term.isEmpty ? '未标注学期' : term);
}

/// A zero-based comparison of the selected courses in each visible semester.
/// No fixed maximum GPA is assumed across undergraduate/graduate scales.
class _SemesterGpaChart extends StatelessWidget {
  const _SemesterGpaChart({required this.visible, required this.included});
  final List<GradeRecord> visible, included;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final available = gradeTerms(
      visible,
    ).where((t) => GradeTerm.parse(t) != null).toList();
    final terms = available.take(6).toList().reversed.toList();
    final periods = terms.map((t) => GradeTerm.parse(t)!).toList();
    final values = [
      for (final term in terms)
        calculateGpa(included.where((r) => r.term == term)).gpa,
    ];
    final maximum = values.fold<double>(
      1,
      (v, n) => n != null && n > v ? n : v,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          available.length > 6 ? '最近6学期 GPA' : '学期 GPA',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < terms.length; i++)
              Expanded(
                child: Tooltip(
                  message:
                      '${GradeTerm.parse(terms[i])?.label ?? terms[i]}  ${values[i]?.toStringAsFixed(2) ?? '未计入'}',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 56,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 24,
                            height: (values[i] ?? 0) / maximum * 56,
                            decoration: BoxDecoration(
                              color: i == terms.length - 1
                                  ? p.dataAccent
                                  : p.dataAccent.withValues(alpha: .7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(periods[i].part == 1 ? periods[i].year : periods[i].year + 1).toString().substring(2)}${switch (periods[i].part) {
                          1 => '秋',
                          2 => '春',
                          3 => '夏',
                          _ => '短',
                        }}',
                        style: TextStyle(color: p.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GradeCourseRow extends StatelessWidget {
  const _GradeCourseRow({
    super.key,
    required this.row,
    required this.selected,
    required this.excludedGeneral,
    required this.onChanged,
  });
  final GradeRecord row;
  final bool selected, excludedGeneral;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      mouseCursor: SystemMouseCursors.basic,
      canRequestFocus: false,
      excludeFromSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
        child: Row(
          children: [
            TooltipVisibility(
              visible: false,
              child: AppCheckbox(
                value: selected,
                label: '${row.title}，${row.score}，计入 GPA',
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTruncatedText(
                    row.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${row.credits} 学分',
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                      if (row.category.isNotEmpty)
                        Text(
                          row.category,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                    ],
                  ),
                  if (row.exclusionReason != null || excludedGeneral) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.exclusionReason ?? '已按自选口径排除通识课程',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  row.score,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.points == null
                      ? '无绩点'
                      : '绩点 ${row.points!.toStringAsFixed(2)}',
                  style: TextStyle(color: p.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
