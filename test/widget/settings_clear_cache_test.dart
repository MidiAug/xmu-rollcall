import 'package:xmu_rollcall/features/exams/exam_cache.dart';
import 'dart:convert';
import 'package:xmu_rollcall/features/exams/exam_models.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _Exams extends ExamNotifier {
  static int loads = 0;
  @override
  Future<ExamSnapshot> build() async {
    loads++;
    final prefs = await SharedPreferences.getInstance();
    return readExamCache(prefs, 1, 2, '20261') ??
        ExamSnapshot(term: '20261', at: DateTime(2026), exams: const []);
  }
}

void main() {
  testWidgets(
    'confirmed clear removes academic cache and refreshes assist memory',
    (tester) async {
      final examAt = DateTime(2026, 11, 4);
      SharedPreferences.setMockInitialValues({
        examCacheKey(1, 2, '20261'): jsonEncode(
          ExamSnapshot(term: '20261', at: examAt, exams: const []).toJson(),
        ),
      });
      _Exams.loads = 0;
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
          examSnapshotProvider.overrideWith(_Exams.new),
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
      final exams = container.listen(examSnapshotProvider, (_, _) {});
      addTearDown(exams.close);
      expect((await container.read(examSnapshotProvider.future)).at, examAt);
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
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        await AcademicScheduleStore.read(2, useUserStart: false),
        isNotNull,
      );
      expect(await TaAssignmentStore(11).read(91), isNotNull);
      expect(_RemoteLists.loads[2], 1);
      await tester.tap(find.text('清除本机课程数据'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        await AcademicScheduleStore.read(2, useUserStart: false),
        isNotNull,
      );
      expect(_RemoteLists.loads[2], 1);
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
      expect(_Exams.loads, 2);
      expect(
        (await container.read(examSnapshotProvider.future)).at,
        DateTime(2026),
      );
      expect(await TaAssignmentStore(11).read(91), isNull);
      AppToast.dismiss();
      expect(tester.takeException(), isNull);
    },
  );
}
