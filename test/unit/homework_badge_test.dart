import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_badge.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('active badge excludes closed, expired, completed and non homework', () {
    final now = DateTime(2026, 10, 29);
    const item = HomeworkItem(id: 1, title: '作业');
    expect(isUnfinishedActiveHomework(item, now), isTrue);
    for (final excluded in [
      item.copyWith(closed: true),
      item.copyWith(status: 'submitted'),
      item.copyWith(status: 'graded'),
      item.copyWith(type: 'exam'),
      item.copyWith(dueAt: now),
      item.copyWith(dueAt: now.subtract(const Duration(seconds: 1))),
    ]) {
      expect(isUnfinishedActiveHomework(excluded, now), isFalse);
    }
  });
  test(
    'badge is disk only, scoped, deduplicated and reacts to submission',
    () async {
      await JsonDiskCache.writeList('homework_submission_1_2', [
        {'submission': 'submitted'},
      ]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          campusNowProvider.overrideWithValue(() => DateTime(2026, 10, 29)),
          campusCachedDataProvider.overrideWith((ref) async {
            final scope = ref.watch(selectedRollcallAccountProvider);
            return CampusCachedData(
              homework: scope == 2
                  ? [const HomeworkItem(id: 3, title: '协助作业')]
                  : [
                      const HomeworkItem(id: 1, title: '主账号作业'),
                      const HomeworkItem(id: 1, title: '重复'),
                      const HomeworkItem(id: 2, title: '已经提交'),
                    ],
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeworkBadgeCountProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(homeworkBadgeCountProvider.future), 1);
      await JsonDiskCache.writeList('homework_submission_1_1', [
        {'submission': 'submitted'},
      ]);
      container.read(homeworkSubmissionRevisionProvider.notifier).state++;
      expect(await container.read(homeworkBadgeCountProvider.future), 0);
      container.read(selectedRollcallAccountProvider.notifier).state = 2;
      expect(await container.read(homeworkBadgeCountProvider.future), 1);
      expect(container.exists(homeworkTodosProvider), isFalse);
    },
  );
}
