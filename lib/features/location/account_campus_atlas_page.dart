import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'campus_atlas_page.dart';
import 'campus_places.dart';
import 'college_campuses.dart';

/// Campus selection is account-aware; the public building directory stays shared.
final selectedCollegeCampusProvider = Provider<Campus?>((ref) {
  final identity = ref.watch(browserIdentityProvider);
  final uid = identity.userId;
  if (uid == null) return null;
  final schedule = ref.watch(academicCachedScheduleProvider(uid));
  return campusForCollege(schedule.valueOrNull?.studentCollege ?? '');
});

class AccountCampusAtlasPage extends ConsumerWidget {
  const AccountCampusAtlasPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(browserIdentityProvider);
    final campus = ref.watch(selectedCollegeCampusProvider);
    return CampusAtlasPage(
      key: ValueKey(identity),
      initialCampus: campus ?? Campus.xiangan,
    );
  }
}
