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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
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
              const SizedBox(height: 24),
              if (!_years.contains(_requestedYear)) ...[
                Text('当前学年校历尚未维护，显示已收录学年。', style: TextStyle(color: p.muted)),
                const SizedBox(height: 16),
              ],
              for (final term in academicTerms.values.where(
                (t) => t.term.startsWith('$_year'),
              )) ...[
                AppHoverSurface(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(switch (term.term[4]) {
                              '1' => '第一学期',
                              '2' => '第二学期',
                              _ => '短学期',
                            }, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          Text(
                            '${term.weeks}周',
                            style: TextStyle(color: p.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 28,
                        runSpacing: 12,
                        children: [
                          for (final field in [
                            ('教学周起始', term.monday),
                            ('学期结束', term.end),
                          ])
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.$1,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: p.muted),
                                ),
                                const SizedBox(height: 6),
                                Text(_date(field.$2)),
                              ],
                            ),
                        ],
                      ),
                      if (!DateUtils.dateOnly(_today).isBefore(term.monday) &&
                          !DateUtils.dateOnly(_today).isAfter(term.end)) ...[
                        const SizedBox(height: 16),
                        Text(
                          '当前第 ${DateUtils.dateOnly(_today).difference(term.monday).inDays ~/ 7 + 1} 周',
                          style: TextStyle(color: p.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '展示已维护的教学周安排，不含完整节假日与临时调课。具体以学校公布校历为准。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.6),
              ),
              const SizedBox(height: 12),
              AppHoverSurface(
                outlined: false,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: () async {
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
                child: Row(
                  children: [
                    Text('校方校历资料', style: TextStyle(color: p.primary)),
                    const SizedBox(width: 8),
                    Icon(Icons.north_east, size: 14, color: p.primary),
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
