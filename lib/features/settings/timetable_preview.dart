import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';

/// Debug-only: switch fixtures to verify weekend columns and late periods.
void openTimetablePreview(BuildContext context) {
  assert(kDebugMode, 'timetable preview is debug-only');
  if (!kDebugMode) return;
  AppPageRoutes.push(context, const TimetablePreviewPage());
}

enum TimetablePreviewScenario {
  /// Mon–Fri, periods 1–8 (午休 + 晚休).
  weekdayTo8,

  /// Mon–Fri + Sat/Sun, still max period 8.
  withWeekend,

  /// Mon–Fri with periods 10–11 (晚休 + deep evening).
  withLateNight,

  /// Sat/Sun + periods 10–11.
  weekendAndLate,
}

extension on TimetablePreviewScenario {
  String get label => switch (this) {
    TimetablePreviewScenario.weekdayTo8 => '工作日 至8',
    TimetablePreviewScenario.withWeekend => '含周末',
    TimetablePreviewScenario.withLateNight => '含10–11',
    TimetablePreviewScenario.weekendAndLate => '周末+晚课',
  };

  String get hint => switch (this) {
    TimetablePreviewScenario.weekdayTo8 => '默认：周一至周五，1–8 节；有午休 / 晚休，无周末列',
    TimetablePreviewScenario.withWeekend => '出现周六、周日列；周末色高亮；列变窄',
    TimetablePreviewScenario.withLateNight => '纵轴到 11 节；保留可读行高，上下滚动查看晚课',
    TimetablePreviewScenario.weekendAndLate =>
      '七列与 11 节：左右查看周末，上下查看晚课；表头和节次保持可见',
  };
}

/// Local fake catalog — not network / not disk.
class TimetablePreviewPage extends StatefulWidget {
  const TimetablePreviewPage({super.key});

  @override
  State<TimetablePreviewPage> createState() => _TimetablePreviewPageState();
}

class _TimetablePreviewPageState extends State<TimetablePreviewPage> {
  TimetablePreviewScenario _scenario = TimetablePreviewScenario.weekendAndLate;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final courses = _coursesFor(_scenario);

    return SubpageScaffold(
      title: '课表样式预览',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 6),
              child: SegmentedButton<TimetablePreviewScenario>(
                segments: [
                  for (final s in TimetablePreviewScenario.values)
                    ButtonSegment(
                      value: s,
                      label: Text(
                        s.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                selected: {_scenario},
                onSelectionChanged: (v) {
                  if (v.isEmpty) return;
                  setState(() => _scenario = v.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                _scenario.hint,
                style: TextStyle(fontSize: 11, height: 1.35, color: p.muted),
              ),
            ),
            Expanded(child: TimetableGridView(courses: courses)),
          ],
        ),
      ),
    );
  }
}

// --- Fake XMU-ish period times (anchor date unused for display) -------------

DateTime _t(int h, int m) => DateTime(2000, 1, 3, h, m);

TimetableSlot _slot(int seq, int sh, int sm, int eh, int em) =>
    TimetableSlot(sequence: seq, start: _t(sh, sm), end: _t(eh, em));

/// Shared period clock so axis labels look consistent across scenarios.
final _periodClock = <int, TimetableSlot>{
  1: _slot(1, 8, 0, 8, 45),
  2: _slot(2, 8, 55, 9, 40),
  3: _slot(3, 10, 0, 10, 45),
  4: _slot(4, 10, 55, 11, 40),
  5: _slot(5, 14, 0, 14, 45),
  6: _slot(6, 14, 55, 15, 40),
  7: _slot(7, 16, 0, 16, 45),
  8: _slot(8, 16, 55, 17, 40),
  9: _slot(9, 19, 0, 19, 45),
  10: _slot(10, 19, 55, 20, 40),
  11: _slot(11, 20, 50, 21, 35),
};

List<TimetableSlot> _seqs(List<int> sequences) => [
  for (final s in sequences) _periodClock[s]!,
];

CatalogCourse _course({
  required String id,
  required String title,
  required Map<int, List<int>> byDay,
  List<String> teachers = const ['预览老师'],
  String? cls,
  String? location,
}) {
  return CatalogCourse(
    id: id,
    title: title,
    instructorNames: teachers,
    teachingClassName: cls,
    location: location,
    timetables: {for (final e in byDay.entries) e.key: _seqs(e.value)},
  );
}

List<CatalogCourse> _coursesFor(TimetablePreviewScenario s) {
  final base = <CatalogCourse>[
    _course(
      id: 'pv-math',
      title: '高等数学',
      cls: '信息1班',
      location: '翔安 A101',
      byDay: {
        1: [1, 2],
        3: [1, 2],
      },
    ),
    _course(
      id: 'pv-eng',
      title: '工程伦理',
      location: '思明 海韵',
      teachers: const ['王老师'],
      byDay: {
        2: [3, 4],
        4: [5, 6],
      },
    ),
    _course(
      id: 'pv-os',
      title: '操作系统',
      location: '翔安 B205',
      byDay: {
        1: [5, 6],
        5: [7, 8],
      },
    ),
    _course(
      id: 'pv-ml',
      title: '机器学习',
      location: '海韵 204',
      byDay: {
        3: [5, 6, 7],
      },
    ),
  ];

  final weekend = <CatalogCourse>[
    _course(
      id: 'pv-sat',
      title: '周六实验',
      location: '实验楼 301',
      byDay: {
        6: [3, 4],
      },
    ),
    _course(
      id: 'pv-sun',
      title: '周日补课',
      location: '线上',
      teachers: const ['李老师'],
      byDay: {
        7: [5, 6],
      },
    ),
  ];

  final late = <CatalogCourse>[
    _course(
      id: 'pv-night',
      title: '晚间研讨',
      location: '嘉庚 305',
      byDay: {
        2: [9, 10],
        4: [10, 11],
      },
    ),
  ];

  return switch (s) {
    TimetablePreviewScenario.weekdayTo8 => base,
    TimetablePreviewScenario.withWeekend => [...base, ...weekend],
    TimetablePreviewScenario.withLateNight => [...base, ...late],
    TimetablePreviewScenario.weekendAndLate => [...base, ...weekend, ...late],
  };
}
