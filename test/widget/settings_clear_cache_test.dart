import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_assignment_store.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

class _RemoteLists extends ActiveRollcallsNotifier {
  static final loads = <int?, int>{};
  @override
  Future<List<RollcallItem>> build(int? uid) async {
    loads[uid] = (loads[uid] ?? 0) + 1;
    return const [];
  }
}

void main() {
  testWidgets(
    'confirmed clear removes academic cache and refreshes assist memory',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await TaAssignmentStore(
        11,
      ).write(91, TaAssignmentSnapshot(const [], DateTime.now()));
      final base = await TaHttpFixture().repository();
      addTearDown(base.dispose);
      var taLoads = 0;
      await AcademicScheduleStore.write(
        2,
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: DateTime.now(),
          rows: const [],
        ),
      );
      final store = SecureStore.memory();
      _RemoteLists.loads.clear();
      final container = ProviderContainer(
        overrides: [
          taRepositoryProvider.overrideWith((ref) async {
            taLoads++;
            final repo = TaGradingRepository(base.http, cacheUserId: 11);
            ref.onDispose(repo.dispose);
            await repo.restoreAssignments(91);
            return repo;
          }),
          authControllerProvider.overrideWith((ref) => _Auth()),
          activeRollcallsProvider.overrideWith(_RemoteLists.new),
          deviceIdentityProvider.overrideWithValue(DeviceIdentity(store)),
        ],
      );
      addTearDown(container.dispose);
      final ta = container.listen(taRepositoryProvider, (_, _) {});
      addTearDown(ta.close);
      expect(
        (await container.read(
          taRepositoryProvider.future,
        )).cachedAssignments(91),
        isNotNull,
      );
      final assist = container.listen(activeRollcallsProvider(2), (_, _) {});
      addTearDown(assist.close);
      await container.read(activeRollcallsProvider(2).future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsDataPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除本机课程数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();
      expect(await AcademicScheduleStore.read(2, useUserStart: false), isNull);
      expect(_RemoteLists.loads[2], 2);
      expect(
        (await container.read(
          taRepositoryProvider.future,
        )).cachedAssignments(91),
        isNull,
      );
      expect(taLoads, 2);
      expect(await TaAssignmentStore(11).read(91), isNull);
      AppToast.dismiss();
      expect(tester.takeException(), isNull);
    },
  );
}
