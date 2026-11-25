import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/location/account_campus_atlas_page.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

void main() {
  testWidgets(
    'actual map uses selected account college and resets after identity switch',
    (tester) async {
      final selected = StateProvider<BrowserIdentity>(
        (ref) => (ownerId: 1, userId: 1, assistId: null),
      );
      AcademicSchedule schedule(String college) => AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime.now(),
        rows: [],
        studentCollege: college,
      );
      final scope = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selected)),
          academicCachedScheduleProvider(
            1,
          ).overrideWith((ref) async => schedule('管理学院')),
          academicCachedScheduleProvider(
            2,
          ).overrideWith((ref) async => schedule('国际学院')),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AccountCampusAtlasPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CampusMap>(find.byType(CampusMap)).center,
        Campus.siming.center,
      );
      // A manual choice must survive unrelated rebuilds within the same account.
      await tester.tap(find.text('翔安校区'));
      await tester.pumpAndSettle();
      scope.invalidate(academicCachedScheduleProvider(1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CampusMap>(find.byType(CampusMap)).center,
        Campus.xiangan.center,
      );
      scope.read(selected.notifier).state = (
        ownerId: 1,
        userId: 2,
        assistId: 2,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CampusMap>(find.byType(CampusMap)).center,
        Campus.zhangzhou.center,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
