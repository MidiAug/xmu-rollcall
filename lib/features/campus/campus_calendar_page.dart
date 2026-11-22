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
    _ => '短学期',
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = _contains(_term, _today);
    final firstMonth = DateTime(_term.monday.year, _term.monday.month);
    final lastMonth = DateTime(_term.end.year, _term.end.month);
    final touch = AppMobileUi.useTouchChrome(context);
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            key: const ValueKey('calendar-range'),
            spacing: AppSpace.md,
            runSpacing: AppSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppShellSelect<int>(
                plain: true,
                compact: true,
                key: const ValueKey('calendar-year'),
                semanticLabel: '选择学年',
                value: _year,
                items: _years.reversed.toList(),
                labelOf: (v) => '$v—${v + 1}学年',
                width: (188 * MediaQuery.textScalerOf(context).scale(1)).clamp(
                  0.0,
                  bounds.maxWidth,
                ),
                menuWidth: 220,
                onChanged: (v) => setState(() {
                  _year = v;
                  _termCode = _initialTerm.term;
                  _month = _initialMonth(_term);
                }),
              ),
              SizedBox(
                width: bounds.maxWidth.clamp(0.0, 288.0),
                child: AppSegmentedControl<String>(
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
                          _ => '短学期',
                        },
                      ),
                  ],
                  onChanged: _selectTerm,
                ),
              ),
            ],
          ),
        ),
      ],
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

    return PageScaffold(
      title: '学年校历',
      onBack: () => Navigator.of(context).maybePop(),
      child: Material(
        color: p.pageBackground(context),
        child: AppPageViewport(
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
                Text('当前学年校历尚未维护，显示已收录学年。', style: TextStyle(color: p.muted)),
              controls,
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, bounds) => bounds.maxWidth >= 760
                    ? IntrinsicHeight(
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
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          month,
                          const SizedBox(height: 24),
                          buildSchedule(expandTerms: false),
                        ],
                      ),
              ),
            ],
          ),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color:
                  DateUtils.dateOnly(
                        today,
                      ).isBefore(DateUtils.addDaysToDate(first, row * 7)) ||
                      !DateUtils.dateOnly(today).isBefore(
                        DateUtils.addDaysToDate(first, (row + 1) * 7),
                      ) ||
                      today.month != month.month
                  ? null
                  : p.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Builder(
                    builder: (context) {
                      final monday = DateUtils.addDaysToDate(first, row * 7);
                      final week =
                          monday.difference(term.monday).inDays ~/ 7 + 1;
                      final inMonth =
                          monday.month == month.month ||
                          DateUtils.addDaysToDate(monday, 6).month ==
                              month.month;
                      return Text(
                        inMonth && week >= 1 && week <= term.weeks
                            ? '$week'
                            : '',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.muted, fontSize: 11),
                      );
                    },
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
                        final isToday = DateUtils.isSameDay(day, today);
                        final week =
                            day.difference(term.monday).inDays ~/ 7 + 1;
                        return Semantics(
                          key: ValueKey(
                            'calendar-day-${day.year}-${day.month}-${day.day}',
                          ),
                          label:
                              '${day.year}年${day.month}月${day.day}日${inTerm ? ' 第$week教学周' : ' 学期外'}${isToday ? ' 今天' : ''}',
                          excludeSemantics: true,
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 38),
                              width: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday ? p.dataAccent : null,
                                borderRadius: BorderRadius.circular(
                                  isToday ? 24 : AppRadii.control,
                                ),
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : inTerm && day.month == month.month
                                      ? p.ink
                                      : p.muted,
                                  fontSize: 14,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
          ),
      ],
    );
  }
}
