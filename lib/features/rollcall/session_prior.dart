import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// Aggregated prior for one course session block.
class SessionPriorSnapshot {
  const SessionPriorSnapshot({
    required this.block,
    required this.weekday,
    required this.pointsMinutes,
    required this.commonStartMinutes,
    required this.commonEndMinutes,
    required this.typeCounts,
    required this.sampleCount,
  });

  final SessionBlock block;
  final int weekday;

  /// Historical rollcall minutes-of-day (newest-first truncated).
  final List<int> pointsMinutes;
  final int commonStartMinutes;
  final int commonEndMinutes;
  final Map<RollcallType, int> typeCounts;
  final int sampleCount;

  bool get hasEnoughSamples => sampleCount >= 2;

  String get headerLabel {
    final day = weekdayLabel(weekday);
    final core =
        '${formatHm(block.coreStart)}–${formatHm(block.coreEnd)}';
    return '$day  ${block.sectionLabel}  $core';
  }
}

const kSessionPriorMaxSamples = 8;

RollcallType rollcallTypeFromLabel(String label) {
  final t = label.trim();
  if (t.contains('雷达')) return RollcallType.radar;
  if (t.contains('数字')) return RollcallType.number;
  if (t.contains('二维码')) return RollcallType.qrcode;
  return RollcallType.unknown;
}

String rollcallTypeZh(RollcallType t) => switch (t) {
      RollcallType.number => '数字',
      RollcallType.radar => '雷达',
      RollcallType.qrcode => '二维码',
      RollcallType.unknown => '其他',
    };

/// Build prior for [block] on [weekday] from course history rows.
SessionPriorSnapshot buildSessionPrior({
  required SessionBlock block,
  required int weekday,
  required List<CourseRollcallRecord> history,
  int maxSamples = kSessionPriorMaxSamples,
}) {
  final matched = <({DateTime at, RollcallType type})>[];
  for (final r in history) {
    if (r.isPlaceholder) continue;
    final at = r.rollcallTime?.toLocal();
    if (at == null) continue;
    if (at.weekday != weekday) continue;
    // Re-anchor block windows onto the history day for containsExpanded.
    final anchored = SessionBlock(
      startSequence: block.startSequence,
      endSequence: block.endSequence,
      coreStart: DateTime(
        at.year,
        at.month,
        at.day,
        block.coreStart.hour,
        block.coreStart.minute,
        block.coreStart.second,
      ),
      coreEnd: DateTime(
        at.year,
        at.month,
        at.day,
        block.coreEnd.hour,
        block.coreEnd.minute,
        block.coreEnd.second,
      ),
    );
    if (!anchored.containsExpanded(at)) continue;
    matched.add((at: at, type: rollcallTypeFromLabel(r.typeLabel)));
  }

  matched.sort((a, b) => b.at.compareTo(a.at));
  final taken = matched.take(maxSamples).toList();
  if (taken.isEmpty) {
    return SessionPriorSnapshot(
      block: block,
      weekday: weekday,
      pointsMinutes: const [],
      commonStartMinutes: minutesOfDay(block.coreStart),
      commonEndMinutes: minutesOfDay(block.coreEnd),
      typeCounts: const {},
      sampleCount: 0,
    );
  }

  final points = [for (final e in taken) minutesOfDay(e.at)]..sort();
  final (lo, hi) = _commonBand(points);
  final counts = <RollcallType, int>{};
  for (final e in taken) {
    counts[e.type] = (counts[e.type] ?? 0) + 1;
  }

  return SessionPriorSnapshot(
    block: block,
    weekday: weekday,
    pointsMinutes: points,
    commonStartMinutes: lo,
    commonEndMinutes: hi,
    typeCounts: counts,
    sampleCount: taken.length,
  );
}

(int, int) _commonBand(List<int> sortedMinutes) {
  if (sortedMinutes.isEmpty) return (0, 0);
  if (sortedMinutes.length < 4) {
    return (sortedMinutes.first, sortedMinutes.last);
  }
  return (
    _percentile(sortedMinutes, 0.25),
    _percentile(sortedMinutes, 0.75),
  );
}

int _percentile(List<int> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final idx = (p * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
  return sorted[idx];
}
