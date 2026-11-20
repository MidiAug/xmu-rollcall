import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'detection_window.dart';

typedef WatchRange = ({DateTime start, DateTime end});

/// Status metadata comes from the same dated lessons used for discovery.
class CourseWatchWindow extends DetectionWindow {
  const CourseWatchWindow({
    required super.intervals,
    required super.hasSchedule,
    required this.hasLessonsToday,
    required this.completedToday,
  }) : super(enabled: true, scheduleBased: true, description: '课前、课间及课后检测');

  final bool hasLessonsToday;
  final bool completedToday;
}

/// Weekly choices are collected per actual date, so alternating rooms/weeks do
/// not create duplicate checkboxes or artificial single-period arrangements.
List<SessionBlock> courseWatchWeeklyBlocks(List<TimetableSlot> slots) {
  final dates = {for (final slot in slots) ...?slot.dates};
  final blocks = <String, SessionBlock>{};
  final groups = dates.isEmpty
      ? [slots.where((s) => s.dates == null).toList()]
      : [
          for (final date in dates)
            slots
                .where((s) => s.dates == null || s.dates!.contains(date))
                .toList(),
        ];
  for (final group in groups) {
    for (final block in courseMeetingBlocks(group)) {
      blocks.putIfAbsent(block.id, () => block);
    }
  }
  return blocks.values.toList()
    ..sort((a, b) => a.startSequence.compareTo(b.startSequence));
}

class CourseWatchScope {
  const CourseWatchScope({
    this.excludedCourses = const {},
    this.excludedMeetings = const {},
  });
  final Set<String> excludedCourses, excludedMeetings;
  static String meetingKey(String courseId, int weekday, String block) =>
      '$courseId/$weekday/$block';
  bool allows(String courseId, int weekday, String block) =>
      !excludedCourses.contains(courseId) &&
      !excludedMeetings.contains(meetingKey(courseId, weekday, block));

  bool? selectionFor(CatalogCourse course) {
    if (excludedCourses.contains(course.id)) return false;
    final choices = [
      for (final day in course.timetables.entries)
        for (final block in courseWatchWeeklyBlocks(day.value))
          allows(course.id, day.key, block.id),
    ];
    if (choices.isEmpty || choices.every((v) => v)) return true;
    return choices.any((v) => v) ? null : false;
  }

  static String _key(int owner, int target) =>
      'course_watch_scope_v1_${owner}_$target';
  static CourseWatchScope fromPrefs(
    SharedPreferences prefs,
    int owner,
    int target,
  ) {
    final saved = prefs.getStringList(_key(owner, target)) ?? [];
    return CourseWatchScope(
      excludedCourses: {
        for (final value in saved)
          if (value.startsWith('course:')) value.substring(7),
      },
      excludedMeetings: {
        for (final value in saved)
          if (value.startsWith('meeting:')) value.substring(8),
      },
    );
  }

  Future<void> save(int owner, int target) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(_key(owner, target), [
      for (final course in excludedCourses) 'course:$course',
      for (final meeting in excludedMeetings) 'meeting:$meeting',
    ])) {
      throw StateError('课程范围未能保存');
    }
  }
}

Future<List<CatalogCourse>> readCourseWatchCourses(int targetId) async {
  final academic = await AcademicScheduleStore.read(targetId, reload: true);
  final catalog = await CourseCatalogStore.read(targetId);
  if (catalog == null || academic == null) return const [];
  return projectAcademicCatalog(catalog, academic).courses
      .where((c) => !c.isTeaching && c.academicMatched)
      .toList(growable: false);
}

/// One dated meeting with each full timetable break, not a fixed duration.
class WatchedLesson {
  WatchedLesson(
    this.courseId,
    this.day,
    this.block,
    List<TimetableSlot> slots,
  ) {
    DateTime onDay(DateTime t) =>
        DateTime(day.year, day.month, day.day, t.hour, t.minute);
    final start = onDay(block.coreStart), end = onDay(block.coreEnd);
    const beforeLead = Duration(minutes: 10);
    const classEdge = Duration(minutes: 5);
    const breakPad = Duration(seconds: 150);
    ranges = [(start: start.subtract(beforeLead), end: start.add(classEdge))];
    final periods = <({DateTime start, DateTime end})>[];
    for (final slot in slots) {
      if (slot.sequence < block.startSequence ||
          slot.lastSequence > block.endSequence) {
        continue;
      }
      if (slot.lastSequence == slot.sequence) {
        periods.add((start: onDay(slot.start), end: onDay(slot.end)));
      } else {
        final clock = coursePeriodClock();
        for (var seq = slot.sequence; seq <= slot.lastSequence; seq++) {
          final time = clock[seq];
          if (time == null) continue;
          final a = DateTime(day.year, day.month, day.day, 0, time.start);
          final b = DateTime(day.year, day.month, day.day, 0, time.end);
          if (!a.isBefore(onDay(slot.start)) && !b.isAfter(onDay(slot.end))) {
            periods.add((start: a, end: b));
          }
        }
      }
    }
    periods.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < periods.length; i++) {
      final a = periods[i - 1].end, b = periods[i].start;
      if (b.isAfter(a)) {
        ranges.add((start: a.subtract(breakPad), end: b.add(breakPad)));
      }
    }
    ranges.add((
      start: end.subtract(classEdge),
      end: end.add(beforeLead),
    ));
  }
  final String courseId;
  final DateTime day;
  final SessionBlock block;
  late final List<WatchRange> ranges;
  String get key => '${TimetableSlot.dateKey(day)}/$courseId/${block.id}';
  bool active(DateTime now) =>
      ranges.any((r) => !now.isBefore(r.start) && now.isBefore(r.end));
}

/// Disk-only desktop planner; nothing here discovers activities or signs in.
class CourseWatch {
  CourseWatch(this.ownerId, this.targetId);
  final int ownerId, targetId;
  List<WatchedLesson> _lessons = [];
  final _observed = <int, String>{};
  Set<String> _completed = {};
  bool _completeProbe = false;
  String get _storageKey => 'course_watch_success_v1_${ownerId}_$targetId';

  Future<DetectionWindow> window({
    required bool completeProbe,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    _completeProbe = completeProbe;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _completed = (prefs.getStringList(_storageKey) ?? []).toSet();
    final scope = CourseWatchScope.fromPrefs(prefs, ownerId, targetId);
    final effective = await readCourseWatchCourses(targetId);
    _lessons = [];
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      for (final course in effective) {
        final slots = (course.timetables[day.weekday] ?? <TimetableSlot>[])
            .where((s) => s.occursOn(day))
            .toList();
        for (final block in courseMeetingBlocks(slots)) {
          if (scope.allows(course.id, day.weekday, block.id)) {
            _lessons.add(WatchedLesson(course.id, day, block, slots));
          }
        }
      }
    }
    final ranges = [
      for (final lesson in _lessons)
        if (completeProbe || !_completed.contains(lesson.key)) ...lesson.ranges,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final today = _lessons.where(
      (l) => l.day == DateTime(now.year, now.month, now.day),
    );
    return CourseWatchWindow(
      hasSchedule: _lessons.isNotEmpty,
      intervals: ranges,
      hasLessonsToday: today.isNotEmpty,
      completedToday:
          !completeProbe &&
          today.isNotEmpty &&
          today.every((l) => _completed.contains(l.key)),
    );
  }

  List<RollcallItem> select(List<RollcallItem> items, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final result = <RollcallItem>[];
    for (final item in items) {
      final matches = _lessons
          .where(
            (l) =>
                l.courseId == item.courseId &&
                l.active(now) &&
                (_completeProbe || !_completed.contains(l.key)),
          )
          .toList();
      if (matches.length != 1) continue;
      // A lingering activity must never migrate to a later dated meeting.
      final observed = _observed[item.rollcallId];
      if (observed != null && observed != matches.single.key) continue;
      _observed.putIfAbsent(item.rollcallId, () => matches.single.key);
      result.add(item);
    }
    return result;
  }

  /// An authoritative answered snapshot also covers manual/external sign-in.
  Future<void> recordAnswered(List<RollcallItem> items) async {
    for (final item in items) {
      if (item.isAnswered) await succeeded(item);
    }
  }

  Future<void> succeeded(RollcallItem item) async {
    final key = _observed[item.rollcallId];
    if (key == null || _completed.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    _completed.add(key);
    final ordered = _completed.toList()..sort();
    if (!await prefs.setStringList(
      _storageKey,
      ordered.reversed.take(300).toList(),
    )) {
      throw StateError('Cannot save course watch completion');
    }
  }
}
