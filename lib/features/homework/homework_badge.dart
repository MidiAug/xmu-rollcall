import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

export 'package:xmu_rollcall/core/cache/cache_revisions.dart'
    show homeworkSubmissionRevisionProvider;

bool isUnfinishedActiveHomework(HomeworkItem item, DateTime now) =>
    item.isHomework &&
    item.closed != true &&
    (item.dueAt == null || item.dueAt!.isAfter(now)) &&
    !item.isSubmitted;

/// Reads scoped disk mirrors only; a badge must not start course discovery.
final homeworkBadgeCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isSignedIn || auth.profile == null) return 0;
  final now =
      ref.watch(campusClockProvider).valueOrNull ??
      ref.read(campusNowProvider)();
  final snapshot = await ref.watch(campusCachedDataProvider.future);
  final ids = <String>{};
  for (final item in snapshot.homework) {
    if (!isUnfinishedActiveHomework(item, now)) continue;
    ids.add('${item.courseId}/${item.id}');
  }
  return ids.length;
});
