typedef PeriodTime = ({int start, int end});

/// Fixed XMU period clock shared by the timetable and schedule editor.
/// https://gs.xmu.edu.cn/info/1721/28561.htm
Map<int, PeriodTime> coursePeriodClock() {
  const starts = [480, 535, 610, 665, 870, 925, 1000, 1055, 1150, 1205, 1260];
  final clock = <int, PeriodTime>{
    for (var i = 0; i < starts.length; i++)
      i + 1: (start: starts[i], end: starts[i] + 45),
  };
  return clock;
}

String periodTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
