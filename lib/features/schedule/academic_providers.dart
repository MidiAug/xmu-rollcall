import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'academic_sync.dart';
import 'academic_timetable_reader.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

final academicRevisionProvider = StateProvider<int>((ref) => 0);
final academicSyncingUidsProvider = StateProvider<Set<int>>((ref) => const {});
final academicSyncProvider = Provider<AcademicSync>((ref) {
  late final AcademicSync sync;
  sync = AcademicSync(
    ref.watch(secureStoreProvider),
    periodic: true,
    createReader: (_) =>
        AcademicTimetableReader(ref.read(academicSessionFactoryProvider)()),
    currentUserId: () => ref.read(selectedRollcallAccountProvider),
    resolveIdentity: ref.watch(academicIdentityResolverProvider),
    onUpdated: (_) {
      ref.read(academicRevisionProvider.notifier).state++;
    },
    onSyncingChanged: (uid, syncing) {
      Future.microtask(() {
        if (sync.isDisposed) return;
        final notifier = ref.read(academicSyncingUidsProvider.notifier);
        final current = notifier.state;
        if (syncing) {
          if (!current.contains(uid)) notifier.state = {...current, uid};
        } else if (current.contains(uid)) {
          notifier.state = {...current}..remove(uid);
        }
      });
    },
  );
  ref.onDispose(sync.dispose);
  return sync;
});

class SemesterInfo {
  const SemesterInfo({
    required this.term,
    this.start,
    this.manual = false,
    this.fetchedAt,
  });
  final String term;
  final DateTime? start;
  final bool manual;
  final DateTime? fetchedAt;
  String weekLabel(DateTime now) {
    if (start == null) return '设置第一周日期';
    if (semesterDate(now).isBefore(start!)) return '尚未开课';
    final week = semesterDate(now).difference(start!).inDays ~/ 7 + 1;
    return week > semesterWeeks(term) ? '学期已结束' : '第$week周';
  }
}

final semesterInfoProvider = FutureProvider.autoDispose
    .family<SemesterInfo, int>((ref, uid) async {
      ref.watch(academicRevisionProvider);
      final raw = await AcademicScheduleStore.read(uid, useUserStart: false);
      final term = raw?.term ?? currentSemester(DateTime.now());
      final manual = await SemesterPreferences.read(uid, term);
      return SemesterInfo(
        term: term,
        start:
            manual ??
            academicMondays[term] ??
            (raw?.anchorFromUser != true ? raw?.monday : null),
        manual: manual != null,
        fetchedAt: raw?.fetchedAt,
      );
    });

/// A direct JW view; TronClass catalog and local supplemental meetings never enter it.
class AcademicTimetableState {
  const AcademicTimetableState({
    this.schedule,
    this.message,
    this.needsLogin = false,
  });
  final AcademicSchedule? schedule;
  final String? message;
  final bool needsLogin;
}

final academicTimetableProvider = FutureProvider.autoDispose
    .family<AcademicTimetableState, int>((ref, uid) async {
      ref.watch(academicRevisionProvider);
      final sync = ref.read(academicSyncProvider);
      final cached = await ref.watch(
        academicCachedScheduleProvider(uid).future,
      );
      final prefs = await SharedPreferences.getInstance();
      if (cached != null &&
          academicScheduleCacheIsFresh(cached, DateTime.now()) &&
          prefs.getString('academic_calendar_missing_$uid') == null) {
        return AcademicTimetableState(
          schedule: cached,
          message: sync.errorFor(uid),
          needsLogin: sync.needsLogin(uid),
        );
      }
      await sync.sync(uid);
      return AcademicTimetableState(
        schedule: await AcademicScheduleStore.read(uid),
        message: sync.errorFor(uid),
        needsLogin: sync.needsLogin(uid),
      );
    });

/// Local snapshot shared by screens; subscribing never starts academic sync.
final academicCachedScheduleProvider = FutureProvider.autoDispose
    .family<AcademicSchedule?, int>((ref, uid) {
      ref.watch(academicRevisionProvider);
      return AcademicScheduleStore.read(uid);
    });

/// Keep normalized display courses while the same schedule is being presented.
final academicDisplayCoursesProvider = Provider.autoDispose
    .family<List<CatalogCourse>, AcademicSchedule>((ref, schedule) {
      return schedule.displayOnlyCourses(const []);
    });
