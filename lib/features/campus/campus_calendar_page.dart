import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

/// Dates and week numbers come only from the maintained teaching periods.
class CampusCalendarPage extends StatefulWidget {
  const CampusCalendarPage({super.key, this.today});
  final DateTime? today;
  @override
  State<CampusCalendarPage> createState() => _CampusCalendarPageState();
}

class _CampusCalendarPageState extends State<CampusCalendarPage> {
  late final _today = DateUtils.dateOnly(widget.today ?? DateTime.now());
  late final _years =
      academicTerms.keys
          .map((t) => int.parse(t.substring(0, 4)))
          .toSet()
          .toList()
        ..sort();
  late final _requestedYear = _today.month >= 8 ? _today.year : _today.year - 1;
  late int _year = _years.contains(_requestedYear)
      ? _requestedYear
      : _years.last;
  List<AcademicTermDates> get _terms =>
      academicTerms.values.where((t) => t.term.startsWith('$_year')).toList();
  bool _contains(AcademicTermDates term, DateTime day) =>
      !day.isBefore(term.monday) && !day.isAfter(term.end);
  AcademicTermDates get _initialTerm =>
      _terms.where((t) => _contains(t, _today)).firstOrNull ??
      _terms.where((t) => t.monday.isAfter(_today)).firstOrNull ??
      _terms.last;
  late String _termCode = _initialTerm.term;
  AcademicTermDates get _term => academicTerms[_termCode]!;
  late DateTime _month = _initialMonth(_term);
  DateTime _initialMonth(AcademicTermDates term) {
    final day = _contains(term, _today) ? _today : term.monday;
    return DateTime(day.year, day.month);
  }

  void _selectTerm(String code) => setState(() {
    _termCode = code;
    _month = _initialMonth(_term);
  });
  String _date(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  String _name(AcademicTermDates term) => switch (term.term[4]) {
    '1' => '第一学期',
    '2' => '第二学期',
    _ => '小学期',
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = _contains(_term, _today);
    final firstMonth = DateTime(_term.monday.year, _term.monday.month);
    final lastMonth = DateTime(_term.end.year, _term.end.month);
    final touch = AppMobileUi.useTouchChrome(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final currentWeek = _today.difference(_term.monday).inDays ~/ 7 + 1;
    final controls = LayoutBuilder(
      builder: (context, bounds) {
        final narrow = touch || bounds.maxWidth < 520;
        final singleRow = narrow && bounds.maxWidth >= 280 && scale <= 1.25;
        final compactYear = narrow && bounds.maxWidth < 360;
        final yearWidth = singleRow
            ? ((compactYear ? 108.0 : 128.0) * scale.clamp(1.0, 1.2)).clamp(
                0.0,
                bounds.maxWidth * 0.45,
              )
            : (188 * scale).clamp(0.0, bounds.maxWidth);
        final yearSelect = AppShellSelect<int>(
          plain: true,
          compact: true,
          key: const ValueKey('calendar-year'),
          semanticLabel: '选择学年',
          value: _year,
          items: _years.reversed.toList(),
          labelOf: (v) => narrow
              ? (compactYear ? '$v-${v + 1}' : '$v-${v + 1}学年')
              : '$v—${v + 1}学年',
          menuLabelOf: (v) => '$v—${v + 1}学年',
          width: yearWidth,
          menuWidth: 220,
          onChanged: (v) => setState(() {
            _year = v;
            _termCode = _initialTerm.term;
            _month = _initialMonth(_term);
          }),
        );
        final termControl = AppSegmentedControl<String>(
          key: const ValueKey('calendar-term'),
          trackOnTouch: true,
          compact: true,
          expanded: true,
          value: _termCode,
          segments: [
            for (final t in _terms)
              AppSegment(
                value: t.term,
                label: switch (t.term[4]) {
                  '1' => '秋季',
                  '2' => '春季',
                  _ => '小学期',
                },
              ),
          ],
          onChanged: _selectTerm,
        );
        if (singleRow) {
          return Row(
            key: const ValueKey('calendar-range'),
            children: [
              yearSelect,
              const SizedBox(width: 8),
              Expanded(child: termControl),
            ],
          );
        }
        return Wrap(
          key: const ValueKey('calendar-range'),
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            yearSelect,
            SizedBox(
              width: bounds.maxWidth.clamp(0.0, 288.0),
              child: termControl,
            ),
          ],
        );
      },
    );
    final month = AppGlassSurface(
      key: const ValueKey('calendar-month-grid'),
      blur: 0,
      opacity: 1,
      borderRadius: BorderRadius.circular(AppRadii.card),
      padding: EdgeInsets.all(touch ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_month.year}年${_month.month}月',
                  key: const ValueKey('calendar-month'),
                  style: TextStyle(
                    fontSize: AppMobileUi.useTouchChrome(context) ? 20 : 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                    color: p.ink,
                  ),
                ),
              ),
              AppIconButton(
                key: const ValueKey('calendar-previous'),
                tooltip: '上个月',
                extent: AppMobileUi.useTouchChrome(context) ? 44 : 36,
                onPressed: _month.isAfter(firstMonth)
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      )
                    : null,
                icon: const Icon(AppIcons.back, size: 18),
              ),
              AppIconButton(
                key: const ValueKey('calendar-next'),
                tooltip: '下个月',
                extent: AppMobileUi.useTouchChrome(context) ? 44 : 36,
                onPressed: _month.isBefore(lastMonth)
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      )
                    : null,
                icon: const Icon(AppIcons.right, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TeachingMonth(term: _term, month: _month, today: _today),
        ],
      ),
    );
    Widget buildSchedule({required bool expandTerms}) {
      Widget buildTermRow(AcademicTermDates term) {
        final row = AppHoverSurface(
          key: ValueKey('calendar-term-row-${term.term}'),
          outlined: false,
          backgroundColor: p.surface,
          quiet: true,
          borderRadius: BorderRadius.zero,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          onTap: () => _selectTerm(term.term),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _name(term),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _termCode == term.term ? p.dataAccent : p.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${term.weeks}周',
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    _termCode == term.term ? AppIcons.check : AppIcons.right,
                    size: 18,
                    color: _termCode == term.term ? p.dataAccent : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    _date(term.monday),
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('—', style: TextStyle(color: p.muted, fontSize: 13)),
                  Text(
                    _date(term.end),
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return expandTerms ? Expanded(child: row) : row;
      }

      final schedulePanel = Panel(
        key: const ValueKey('calendar-schedule-panel'),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, term) in _terms.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: p.border,
                ),
              buildTermRow(term),
            ],
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active) ...[
            Panel(
              outlined: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('教学周进度', style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('第 ', style: TextStyle(color: p.muted)),
                      Text(
                        '${_today.difference(_term.monday).inDays ~/ 7 + 1}',
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' / ${_term.weeks} 周',
                        style: TextStyle(color: p.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value:
                        (_today.difference(_term.monday).inDays ~/ 7 + 1) /
                        _term.weeks,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: p.primary,
                    backgroundColor: p.track,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('学期安排', style: AppTypography.sectionTitle.copyWith(color: p.ink)),
          const SizedBox(height: 10),
          if (expandTerms) Expanded(child: schedulePanel) else schedulePanel,
        ],
      );
    }

    Widget buildMobileSummary() => Panel(
      key: const ValueKey('calendar-summary-card'),
      outlined: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_date(_term.monday)} — ${_date(_term.end)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                active
                    ? '第 $currentWeek / ${_term.weeks} 周'
                    : '共 ${_term.weeks} 周',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? p.dataAccent : p.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (currentWeek / _term.weeks).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: p.primary,
              backgroundColor: p.track,
            ),
          ],
        ],
      ),
    );

    return SubpageScaffold(
      title: '学年校历',
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, insets) => ListView(
          padding:
              insets +
              EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                20,
                AppSpace.pageXOf(context),
                32,
              ),
          children: [
            if (!_years.contains(_requestedYear))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '当前学年校历尚未维护，显示已收录学年。',
                  style: TextStyle(color: p.muted),
                ),
              ),
            LayoutBuilder(
              builder: (context, bounds) {
                if (bounds.maxWidth >= 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      controls,
                      const SizedBox(height: 24),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 13, child: month),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 7,
                              child: buildSchedule(expandTerms: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    controls,
                    const SizedBox(height: 12),
                    buildMobileSummary(),
                    const SizedBox(height: 16),
                    month,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TeachingMonth extends StatelessWidget {
  const _TeachingMonth({
    required this.term,
    required this.month,
    required this.today,
  });
  final AcademicTermDates term;
  final DateTime month, today;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final first = DateUtils.addDaysToDate(month, 1 - month.weekday);
    // Keep month navigation and the semester rows stationary across months.
    const rows = 6;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '周',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 11),
              ),
            ),
            for (final label in ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ['六', '日'].contains(label) ? p.dataAccent : p.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < rows; row++)
          Builder(
            builder: (context) {
              final rowStart = DateUtils.addDaysToDate(first, row * 7);
              final rowEnd = DateUtils.addDaysToDate(first, (row + 1) * 7);
              final todayDate = DateUtils.dateOnly(today);
              final inCurrentWeek =
                  !todayDate.isBefore(rowStart) &&
                  todayDate.isBefore(rowEnd) &&
                  today.month == month.month;
              final week = rowStart.difference(term.monday).inDays ~/ 7 + 1;
              final rowInMonth =
                  rowStart.month == month.month ||
                  DateUtils.addDaysToDate(rowStart, 6).month == month.month;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: inCurrentWeek ? p.accentSoft : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        rowInMonth && week >= 1 && week <= term.weeks
                            ? '$week'
                            : '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: inCurrentWeek ? p.dataAccent : p.muted,
                          fontSize: 11,
                          fontWeight: inCurrentWeek ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = DateUtils.addDaysToDate(
                              first,
                              row * 7 + column,
                            );
                            final inTerm =
                                !day.isBefore(term.monday) &&
                                !day.isAfter(term.end);
                            final inMonth = day.month == month.month;
                            final isWeekend = day.weekday >= 6;
                            final isToday = DateUtils.isSameDay(day, today);
                            final dayWeek =
                                day.difference(term.monday).inDays ~/ 7 + 1;
                            final Color dayColor;
                            final FontWeight dayWeight;
                            if (isToday) {
                              dayColor = Theme.of(
                                context,
                              ).colorScheme.onPrimary;
                              dayWeight = FontWeight.w700;
                            } else if (!inMonth) {
                              dayColor = isWeekend
                                  ? p.dataAccent.withValues(
                                      alpha: p.isDark ? 0.34 : 0.36,
                                    )
                                  : (p.isDark ? p.ink : p.muted).withValues(
                                      alpha: p.isDark ? 0.28 : 0.32,
                                    );
                              dayWeight = FontWeight.w400;
                            } else if (inTerm) {
                              dayColor = isWeekend ? p.dataAccent : p.ink;
                              dayWeight = FontWeight.w600;
                            } else {
                              dayColor = p.muted.withValues(
                                alpha: p.isDark ? 0.58 : 0.65,
                              );
                              dayWeight = FontWeight.w500;
                            }
                            return Semantics(
                              key: ValueKey(
                                'calendar-day-${day.year}-${day.month}-${day.day}',
                              ),
                              label:
                                  '${day.year}年${day.month}月${day.day}日${inTerm ? ' 第$dayWeek教学周' : ' 学期外'}${isToday ? ' 今天' : ''}',
                              excludeSemantics: true,
                              child: Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 38,
                                  ),
                                  width: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isToday ? p.primary : null,
                                    borderRadius: BorderRadius.circular(
                                      isToday ? 10 : AppRadii.control,
                                    ),
                                  ),
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: dayColor,
                                      fontSize: 14,
                                      fontWeight: dayWeight,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
