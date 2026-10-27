import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';

final academicRevisionProvider = StateProvider<int>((ref) => 0);
final academicSyncProvider = Provider<AcademicSync>((ref) {
  final sync = AcademicSync(
    ref.watch(secureStoreProvider),
    periodic: true,
    currentSso: () => ref.read(tronHttpClientProvider).cookieJar,
    onUpdated: (_) {
      ref.read(academicRevisionProvider.notifier).state++;
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
    return week > 30 ? '学期已结束' : '第$week周';
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
      await sync.sync(uid);
      return AcademicTimetableState(
        schedule: await AcademicScheduleStore.read(uid),
        message: sync.errorFor(uid),
        needsLogin: sync.needsLogin(uid),
      );
    });
