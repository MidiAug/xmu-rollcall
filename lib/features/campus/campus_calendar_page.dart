import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

/// Read-only view of maintained published teaching periods, never estimates.
class CampusCalendarPage extends StatefulWidget {
  const CampusCalendarPage({super.key, this.today});
  final DateTime? today;
  @override
  State<CampusCalendarPage> createState() => _CampusCalendarPageState();
}

class _CampusCalendarPageState extends State<CampusCalendarPage> {
  late final _today = widget.today ?? DateTime.now();
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
  String _date(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PageScaffold(
      title: '学年校历',
      onBack: () => Navigator.of(context).maybePop(),
      child: Material(
        color: p.canvas,
        child: AppContentColumn(
          maxWidth: 960,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpace.pageXOf(context),
              8,
              AppSpace.pageXOf(context),
              32,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppShellSelect<int>(
                  semanticLabel: '选择学年',
                  value: _year,
                  items: _years.reversed.toList(),
                  labelOf: (v) => '$v—${v + 1}学年',
                  width: 220,
                  menuWidth: 220,
                  onChanged: (v) => setState(() => _year = v),
                ),
              ),
              const SizedBox(height: 20),
              if (!_years.contains(_requestedYear)) ...[
                Text('当前学年校历尚未维护，显示已收录学年。', style: TextStyle(color: p.muted)),
                const SizedBox(height: 16),
              ],
              AppGlassSurface(
                blur: 0,
                opacity: 1,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Column(
                  children: [
                    for (final (index, term)
                        in academicTerms.values
                            .where((t) => t.term.startsWith('$_year'))
                            .indexed) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 22,
                          endIndent: 22,
                          color: p.border,
                        ),
                      _term(context, term),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '展示已维护的教学周安排，不含完整节假日与临时调课。具体以学校公布校历为准。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.6),
              ),
              const SizedBox(height: 12),
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

  Widget _term(BuildContext context, AcademicTermDates term) {
    final p = AppPalette.of(context);
    final today = DateUtils.dateOnly(_today);
    final active = !today.isBefore(term.monday) && !today.isAfter(term.end);
    final week = today.difference(term.monday).inDays ~/ 7 + 1;
    final elapsed = today.isAfter(term.end)
        ? term.weeks
        : active
        ? week
        : 0;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconSurface(child: Icon(AppIcons.calendar)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  switch (term.term[4]) {
                    '1' => '第一学期',
                    '2' => '第二学期',
                    _ => '短学期',
                  },
                  style: TextStyle(
                    fontSize: 16,
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${term.weeks}周',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              for (final field in [('教学周起始', term.monday), ('学期结束', term.end)])
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.$1,
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _date(field.$2),
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var n = 1; n <= term.weeks; n++) ...[
                  if (n > 1) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: n <= elapsed
                            ? p.primary.withValues(alpha: active ? .85 : .28)
                            : p.controlSurface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (active) ...[
            const SizedBox(height: 12),
            AppStatusBadge('当前第 $week 周'),
          ],
        ],
      ),
    );
  }
}
