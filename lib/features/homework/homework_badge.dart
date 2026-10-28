import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

final homeworkSubmissionRevisionProvider = StateProvider<int>((ref) => 0);

bool isUnfinishedActiveHomework(HomeworkItem item, DateTime now) =>
    item.isHomework &&
    item.closed != true &&
    (item.dueAt == null || item.dueAt!.isAfter(now)) &&
    !const {
      'submitted',
      'graded',
      'completed',
      '已提交',
      '已批改',
      '已完成',
    }.contains(item.status.trim().toLowerCase());

/// Reads scoped disk mirrors only; a badge must not start course discovery.
final homeworkBadgeCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(homeworkSubmissionRevisionProvider);
  final auth = ref.watch(authControllerProvider);
  final scope = ref.watch(selectedRollcallAccountProvider);
  if (!auth.isSignedIn || auth.profile == null) return 0;
  final uid = scope ?? auth.profile!.id;
  final now =
      ref.watch(campusClockProvider).valueOrNull ??
      ref.read(campusNowProvider)();
  final snapshot = await ref.watch(campusCachedDataProvider.future);
  final ids = <String>{};
  for (final item in snapshot.homework) {
    if (!isUnfinishedActiveHomework(item, now)) continue;
    final disk = await JsonDiskCache.readList(
      'homework_submission_${uid}_${item.id}',
    );
    if (disk != null &&
        disk.items.isNotEmpty &&
        HomeworkSubmissionState.fromJson(disk.items.first).submission ==
            HomeworkSubmission.submitted) {
      continue;
    }
    ids.add('${item.courseId}/${item.id}');
  }
  return ids.length;
});
