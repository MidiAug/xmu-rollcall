// XMU course session blocks from TronClass `timetables` (pure logic).

/// One official period row from `timetable_slot`.
class TimetableSlot {
  const TimetableSlot({
    required this.sequence,
    required this.start,
    required this.end,
  });

  /// 1..11 period index.
  final int sequence;

  /// Time-of-day on an arbitrary anchor date (date part ignored in compares).
  final DateTime start;
  final DateTime end;
}

/// Contiguous periods for one course meeting (e.g. 5–6).
class SessionBlock {
  const SessionBlock({
    required this.startSequence,
    required this.endSequence,
    required this.coreStart,
    required this.coreEnd,
  });

  final int startSequence;
  final int endSequence;
  final DateTime coreStart;
  final DateTime coreEnd;

  /// Stable id such as `5-6`.
  String get id =>
      startSequence == endSequence ? '$startSequence' : '$startSequence-$endSequence';

  String get sectionLabel {
    if (startSequence == endSequence) return '第$startSequence节';
    return '第$startSequence–$endSequence节';
  }

  static const preBuffer = Duration(minutes: 25);
  static const postBuffer = Duration(minutes: 5);

  DateTime get windowStart => coreStart.subtract(preBuffer);
  DateTime get windowEnd => coreEnd.add(postBuffer);

  bool containsExpanded(DateTime t) {
    final m = _minutes(t);
    return m >= _minutes(windowStart) && m <= _minutes(windowEnd);
  }

  bool containsCore(DateTime t) {
    final m = _minutes(t);
    return m >= _minutes(coreStart) && m <= _minutes(coreEnd);
  }
}

/// Merge sorted contiguous [TimetableSlot]s into [SessionBlock]s.
///
/// Adjacent sequences only stay in one block when the gap between the previous
/// `end` and next `start` is a short break (≤15 min). The XMU 30-minute rests
/// (after 2 / after 6) start a new block even if sequences are consecutive.
List<SessionBlock> splitContiguousBlocks(List<TimetableSlot> slots) {
  if (slots.isEmpty) return const [];
  final sorted = [...slots]..sort((a, b) => a.sequence.compareTo(b.sequence));
  final out = <SessionBlock>[];
  var run = <TimetableSlot>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final s = sorted[i];
    final prev = run.last;
    final gap = s.start.difference(prev.end);
    final shortBreak = !gap.isNegative && gap <= const Duration(minutes: 15);
    if (s.sequence == prev.sequence + 1 && shortBreak) {
      run.add(s);
    } else {
      out.add(_blockFromRun(run));
      run = [s];
    }
  }
  out.add(_blockFromRun(run));
  return out;
}

SessionBlock _blockFromRun(List<TimetableSlot> run) {
  return SessionBlock(
    startSequence: run.first.sequence,
    endSequence: run.last.sequence,
    coreStart: run.first.start,
    coreEnd: run.last.end,
  );
}

/// Pick the session block for [localTime], or null if unscoped.
///
/// Overlap / big-break: prefer the **next** block (upcoming class pre-sign).
SessionBlock? resolveBlock(List<SessionBlock> blocks, DateTime localTime) {
  if (blocks.isEmpty) return null;
  final hits = [
    for (final b in blocks)
      if (b.containsExpanded(localTime)) b,
  ];
  if (hits.isEmpty) return null;
  if (hits.length == 1) return hits.first;

  final m = _minutes(localTime);
  // Prefer upcoming: smallest coreStart that is still >= now, else nearest next.
  SessionBlock? upcoming;
  for (final b in hits) {
    if (_minutes(b.coreStart) >= m) {
      if (upcoming == null ||
          _minutes(b.coreStart) < _minutes(upcoming.coreStart)) {
        upcoming = b;
      }
    }
  }
  if (upcoming != null) return upcoming;

  // All hit blocks already started — pick the one with latest coreStart
  // among hits that still contain now in expanded window (later segment).
  hits.sort((a, b) => _minutes(a.coreStart).compareTo(_minutes(b.coreStart)));
  return hits.last;
}

/// Parse `HH:mm:ss` or `HH:mm` into today's [DateTime] on [anchor] date.
DateTime? parseDayTime(String raw, DateTime anchor) {
  final parts = raw.trim().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final min = int.tryParse(parts[1]);
  final sec = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (h == null || min == null) return null;
  return DateTime(anchor.year, anchor.month, anchor.day, h, min, sec);
}

/// Minutes since local midnight.
int minutesOfDay(DateTime t) => _minutes(t);

int _minutes(DateTime t) => t.hour * 60 + t.minute;

/// Format `HH:mm` in local clock.
String formatHm(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

const _weekdayNames = <int, String>{
  1: '周一',
  2: '周二',
  3: '周三',
  4: '周四',
  5: '周五',
  6: '周六',
  7: '周日',
};

String weekdayLabel(int weekday) => _weekdayNames[weekday] ?? '周$weekday';

/// Parse TronClass `timetables` map for one course.
///
/// Keys are weekday strings `"1"`…`"7"` (Monday=1), matching [DateTime.weekday].
Map<int, List<TimetableSlot>> parseTimetables(
  dynamic raw, {
  DateTime? anchor,
}) {
  if (raw is! Map) return const {};
  final day = anchor ?? DateTime(2000, 1, 3); // Monday
  final out = <int, List<TimetableSlot>>{};
  for (final e in raw.entries) {
    final wd = int.tryParse('${e.key}');
    if (wd == null || wd < 1 || wd > 7) continue;
    final list = e.value;
    if (list is! List) continue;
    final slots = <TimetableSlot>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final slotRaw = m['timetable_slot'];
      final slot = slotRaw is Map
          ? Map<String, dynamic>.from(slotRaw)
          : m;
      final seq = slot['sequence'];
      final seqN = seq is num ? seq.toInt() : int.tryParse('$seq');
      final startS = '${slot['start_time'] ?? ''}';
      final endS = '${slot['end_time'] ?? ''}';
      final start = parseDayTime(startS, day);
      final end = parseDayTime(endS, day);
      if (seqN == null || start == null || end == null) continue;
      slots.add(TimetableSlot(sequence: seqN, start: start, end: end));
    }
    if (slots.isNotEmpty) out[wd] = slots;
  }
  return out;
}
