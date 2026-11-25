import 'dart:convert';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'lecture_provider.dart';
import 'lecture_requirement_provider.dart';

/// Directory summaries never log in or fan out to the lecture/academic servers.
final cachedLectureSummaryProvider =
    FutureProvider.autoDispose<({int? success, int? required})>((ref) async {
      ref.watch(lectureCacheRevisionProvider);
      final identity = ref.watch(browserIdentityProvider);
      if (identity.userId == null) return (success: null, required: null);
      final p = await SharedPreferences.getInstance();
      int? success, required;
      try {
        final raw = p.getString(lectureCacheKey(identity));
        if (raw != null) {
          final page = lectureMap(lectureMap(raw)['page']);
          success = LecturePage.fromCache(page).successCount;
        }
        final plan = p.getString(lectureRequirementKey(identity));
        if (plan != null) {
          required = LectureRequirement.fromJson(
            Map<String, dynamic>.from(jsonDecode(plan) as Map),
          ).minimum;
        }
      } on FormatException {
        /* Missing data stays unknown, never zero. */
      } on TypeError {
        /* Cache from an older app. */
      }
      return (success: success, required: required);
    });

class LectureProgressTrailing extends ConsumerWidget {
  const LectureProgressTrailing({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cachedLectureSummaryProvider);
    final value = state.isReloading ? null : state.valueOrNull;
    final success = value?.success, required = value?.required;
    if (success == null) return const SizedBox.shrink();
    return Text(
      required == null ? '$success场' : '$success/$required',
      style: AppTypography.caption.copyWith(
        color: AppPalette.of(context).muted,
      ),
    );
  }
}
