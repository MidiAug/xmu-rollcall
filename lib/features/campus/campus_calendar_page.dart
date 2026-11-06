import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
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
    return PageScaffold(
      title: '学年校历',
      onBack: () => Navigator.of(context).maybePop(),
      child: Material(
        color: p.canvas,
        child: AppPageViewport(
          maxWidth: 960,
          builder: (context, insets) => ListView(
            padding:
                insets +
                EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  8,
                  AppSpace.pageXOf(context),
                  32,
                ),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppShellSelect<int>(
                    semanticLabel: '选择学年',
                    value: _year,
                    items: _years.reversed.toList(),
                    labelOf: (v) => '$v—${v + 1}学年',
                    width: 210,
                    menuWidth: 220,
                    onChanged: (v) => setState(() {
                      _year = v;
                      _termCode = _initialTerm.term;
                      _month = _initialMonth(_term);
                    }),
                  ),
                  if (active)
                    AppStatusBadge(
                      '当前第 ${_today.difference(_term.monday).inDays ~/ 7 + 1} 周',
                    ),
                ],
              ),
              if (!_years.contains(_requestedYear)) ...[
                const SizedBox(height: 12),
                Text('当前学年校历尚未维护，显示已收录学年。', style: TextStyle(color: p.muted)),
              ],
              const SizedBox(height: 20),
              Panel(
                key: const ValueKey('calendar-month-grid'),
                padding: EdgeInsets.all(
                  AppMobileUi.useTouchChrome(context) ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, bounds) => Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: bounds.maxWidth.clamp(0.0, 360.0),
                          child: AppSegmentedControl<String>(
                            key: const ValueKey('calendar-term'),
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
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_month.year}年${_month.month}月',
                            key: const ValueKey('calendar-month'),
                            style: TextStyle(
                              fontSize: AppMobileUi.useTouchChrome(context)
                                  ? 20
                                  : 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.5,
                              color: p.ink,
                            ),
                          ),
                        ),
                        AppIconButton(
                          key: const ValueKey('calendar-previous'),
                          tooltip: '上个月',
                          hoverOutline: true,
                          extent: AppMobileUi.useTouchChrome(context) ? 44 : 36,
                          onPressed: _month.isAfter(firstMonth)
                              ? () => setState(
                                  () => _month = DateTime(
                                    _month.year,
                                    _month.month - 1,
                                  ),
                                )
                              : null,
                          icon: const Icon(AppIcons.back, size: 18),
                        ),
                        AppIconButton(
                          key: const ValueKey('calendar-next'),
                          tooltip: '下个月',
                          hoverOutline: true,
                          extent: AppMobileUi.useTouchChrome(context) ? 44 : 36,
                          onPressed: _month.isBefore(lastMonth)
                              ? () => setState(
                                  () => _month = DateTime(
                                    _month.year,
                                    _month.month + 1,
                                  ),
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
              ),
              const SizedBox(height: 28),
              Text(
                '学期安排',
                style: AppTypography.sectionTitle.copyWith(color: p.ink),
              ),
              const SizedBox(height: 12),
              Panel(
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
                      AppHoverSurface(
                        key: ValueKey('calendar-term-row-${term.term}'),
                        outlined: false,
                        backgroundColor: _termCode == term.term
                            ? p.selected
                            : p.surface,
                        hoverColor: _termCode == term.term
                            ? p.selected
                            : p.hover,
                        pressedColor: _termCode == term.term
                            ? p.selected
                            : p.controlPressed,
                        padding: const EdgeInsets.all(20),
                        onTap: () => _selectTerm(term.term),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _name(term),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: p.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${term.weeks}周',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.muted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  _termCode == term.term
                                      ? AppIcons.check
                                      : AppIcons.right,
                                  size: 16,
                                  color: p.dataAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, bounds) => Wrap(
                                spacing: 32,
                                runSpacing: 12,
                                children: [
                                  for (final field in [
                                    ('教学周起始', term.monday),
                                    ('学期结束', term.end),
                                  ])
                                    SizedBox(
                                      width: bounds.maxWidth < 300
                                          ? bounds.maxWidth
                                          : 180,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            field.$1,
                                            style: TextStyle(
                                              color: p.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _date(field.$2),
                                            style: TextStyle(
                                              color: p.ink,
                                              fontSize: 14,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '展示已维护的教学周安排，不含完整节假日与临时调课。具体以学校公布校历为准。',
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: '校方校历资料',
                  icon: AppIcons.externalLink,
                  kind: AppButtonKind.quiet,
                  onPressed: () async {
                    try {
                      if (!await launchUrl(
                            Uri.parse(
                              'https://dblab.xmu.edu.cn/topic/share/school-calendar/',
                            ),
                            mode: LaunchMode.externalApplication,
                          ) &&
                          context.mounted) {
                        AppToast.show(context, '无法打开校历来源');
                      }
                    } catch (_) {
                      if (context.mounted) AppToast.show(context, '无法打开校历来源');
                    }
                  },
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
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
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
                        if (day.month != month.month) {
                          return const SizedBox(height: 38);
                        }
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
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : inTerm
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
