import 'package:xmu_rollcall/features/rollcall/session_block.dart';

String formatTeachingWeeks(Iterable<int> values) {
  final weeks = values.toSet().toList()..sort();
  if (weeks.isEmpty) return '';
  if (weeks.length == 1) return '第${weeks.first}周';
  bool step(int n) => List.generate(
    weeks.length - 1,
    (i) => weeks[i + 1] - weeks[i],
  ).every((v) => v == n);
  if (step(1)) return '${weeks.first}-${weeks.last}周';
  if (step(2)) {
    return '${weeks.first == 2 ? 1 : weeks.first}-${weeks.last}${weeks.first.isEven ? '双' : '单'}周';
  }
  final ranges = <String>[];
  var first = weeks.first, last = first;
  void flush() => ranges.add(first == last ? '$first' : '$first-$last');
  for (final week in weeks.skip(1)) {
    if (week != last + 1) {
      flush();
      first = week;
    }
    last = week;
  }
  flush();
  return '${ranges.join('、')}周';
}

String joinAcademicRooms(Iterable<String> values) {
  final rooms =
      values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList()
        ..sort();
  if (rooms.length < 2) return rooms.firstOrNull ?? '';
  final parts = rooms
      .map(
        (v) => RegExp(r'^(.*?)([A-Za-z]?\d{3,5}(?:[-－]\d+)?)$').firstMatch(v),
      )
      .toList();
  if (parts.every((p) => p != null && p.group(1) == parts.first?.group(1))) {
    return '${parts.first!.group(1)}${parts.map((p) => p!.group(2)).join('、')}';
  }
  return rooms.join('、');
}

/// One course/class/weekday at a time. Aggregate rooms per actual date first,
/// then collect equal patterns and merge contiguous periods within a day-part.
/// Raw rows and each effective date remain intact in storage.
List<TimetableSlot> normalizeAcademicSlots(
  List<TimetableSlot> slots,
  DateTime monday,
) {
  final byDay =
      <String, ({TimetableSlot base, Set<String> rooms, Set<String> dates})>{};
  for (final slot in slots) {
    for (final date in slot.dates ?? <String>{}) {
      final key = '${slot.sequence}/${slot.lastSequence}/$date';
      final bucket = byDay.putIfAbsent(
        key,
        () => (base: slot, rooms: <String>{}, dates: {date}),
      );
      if (slot.classroom?.isNotEmpty == true) bucket.rooms.add(slot.classroom!);
    }
  }
  final patterns =
      <String, ({TimetableSlot base, String room, Set<String> dates})>{};
  for (final day in byDay.values) {
    final room = joinAcademicRooms(day.rooms);
    final key = '${day.base.sequence}/${day.base.lastSequence}/$room';
    patterns
        .putIfAbsent(key, () => (base: day.base, room: room, dates: <String>{}))
        .dates
        .addAll(day.dates);
  }
  String dateKey(Set<String> dates) => (dates.toList()..sort()).join(',');
  TimetableSlot make(
    TimetableSlot base,
    String room,
    Set<String> dates, {
    TimetableSlot? end,
  }) => TimetableSlot(
    sequence: base.sequence,
    endSequence: end?.lastSequence ?? base.lastSequence,
    start: base.start,
    end: end?.end ?? base.end,
    classroom: room,
    dates: dates,
    weekLabel: formatTeachingWeeks(
      dates.map((d) => DateTime.parse(d).difference(monday).inDays ~/ 7 + 1),
    ),
  );
  final sorted =
      [for (final p in patterns.values) make(p.base, p.room, p.dates)]
        ..sort((a, b) {
          final identity = '${dateKey(a.dates!)}/${a.classroom}'.compareTo(
            '${dateKey(b.dates!)}/${b.classroom}',
          );
          return identity != 0 ? identity : a.sequence.compareTo(b.sequence);
        });
  final result = <TimetableSlot>[];
  for (final slot in sorted) {
    final previous = result.lastOrNull;
    final crossesRest =
        previous != null &&
        ((previous.lastSequence <= 4 && slot.sequence >= 5) ||
            (previous.lastSequence <= 8 && slot.sequence >= 9));
    if (previous != null &&
        !crossesRest &&
        slot.sequence <= previous.lastSequence + 1 &&
        dateKey(previous.dates!) == dateKey(slot.dates!) &&
        previous.classroom == slot.classroom) {
      result[result.length - 1] = make(
        previous,
        previous.classroom ?? '',
        previous.dates!,
        end: slot.lastSequence > previous.lastSequence ? slot : previous,
      );
    } else {
      result.add(slot);
    }
  }
  return result..sort(
    (a, b) => a.sequence != b.sequence
        ? a.sequence.compareTo(b.sequence)
        : dateKey(a.dates!).compareTo(dateKey(b.dates!)),
  );
}
