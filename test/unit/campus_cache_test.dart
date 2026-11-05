import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_badge.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试用户'),
    );
  }
  void signedOut() => state = const AuthState(status: AuthStatus.signedOut);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'course-only homework reaches real summary and badge without network',
    () async {
      for (final uid in [1, 2]) {
        await CourseCatalogStore.write(
          uid,
          CourseCatalogSnapshot(
            fetchedAt: DateTime.now(),
            courses: [
              CatalogCourse(
                id: '10',
                title: '账号$uid课程',
                roles: const ['student'],
                timetables: {
                  1: [
                    TimetableSlot(
                      sequence: 1,
                      start: DateTime(2000, 1, 3, 8),
                      end: DateTime(2000, 1, 3, 9),
                    ),
                  ],
                },
              ),
            ],
          ),
        );
        await JsonDiskCache.writeList('homework_todos_$uid', []);
        await JsonDiskCache.writeList('course_homework_${uid}_10', [
          {'id': uid, 'title': '账号$uid独有作业', 'due_at': '2099-01-01T00:00:00'},
          {'id': 99, 'title': '已完成', 'status': 'submitted'},
        ]);
      }
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: const AssistUiState(ready: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeworkBadgeCountProvider, (_, _) {});
      addTearDown(sub.close);
      for (final uid in [1, 2]) {
        container.read(selectedRollcallAccountProvider.notifier).state =
            uid == 1 ? null : uid;
        expect(await container.read(homeworkBadgeCountProvider.future), 1);
        final summary = await container.read(campusCachedDataProvider.future);
        expect(summary.homework.single.title, '账号$uid独有作业');
        expect(summary.homework.single.courseName, '账号$uid课程');
      }
      expect(container.exists(homeworkOverviewProvider), isFalse);
      expect(container.exists(homeworkTodosProvider), isFalse);
    },
  );
  test(
    'summary reads isolated disk snapshots without mounting network providers',
    () async {
      final at = DateTime(2026, 10, 28);
      for (final uid in [1, 2]) {
        await AcademicScheduleStore.write(
          uid,
          AcademicSchedule(
            term: '20261',
            monday: DateTime(2026, 9, 7),
            fetchedAt: at,
            rows: [
              {'KCDM': 'course-$uid', 'KCMC': '账号$uid课表'},
            ].map(AcademicCourseRow.fromJson).toList(),
          ),
        );
        await CourseCatalogStore.write(
          uid,
          CourseCatalogSnapshot(
            fetchedAt: at,
            courses: [
              CatalogCourse(id: '10', title: '账号$uid课程', roles: ['student']),
              CatalogCourse(
                id: '11',
                title: '助教课程',
                roles: ['student_assistant'],
              ),
            ],
          ),
        );
        await JsonDiskCache.writeList('homework_todos_$uid', [
          {'id': uid, 'title': '账号$uid待办', 'course_id': 10},
          {'id': 12, 'title': '助教任务', 'course_id': 11},
          {'id': 13, 'title': '旧学期任务', 'course_id': 99},
          {'id': 14, 'title': '已提交', 'course_id': 10, 'status': 'submitted'},
          {'id': 15, 'title': '已关闭', 'course_id': 10, 'is_closed': true},
          {'id': 16, 'title': '公告', 'course_id': 10, 'type': 'notice'},
        ]);
      }
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: const AssistUiState(ready: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(campusCachedDataProvider, (_, _) {});
      addTearDown(sub.close);
      final owner = await container.read(campusCachedDataProvider.future);
      expect(owner.homework.map((i) => i.title), ['账号1待办']);
      expect(owner.schedule?.rows.single.courseName, '账号1课表');
      expect(owner.homework.single.courseName, '账号1课程');
      container.read(selectedRollcallAccountProvider.notifier).state = 2;
      final peer = await container.read(campusCachedDataProvider.future);
      expect(peer.homework.map((i) => i.title), ['账号2待办']);
      expect(peer.schedule?.rows.single.courseName, '账号2课表');
      expect(peer.homework.single.courseName, '账号2课程');
      await JsonDiskCache.writeList('homework_todos_2', [
        {'id': 20, 'title': '更新后的待办', 'course_id': 10},
      ]);
      container.read(homeworkCacheRevisionProvider.notifier).state++;
      expect(
        (await container.read(
          campusCachedDataProvider.future,
        )).homework.single.title,
        '更新后的待办',
      );
      expect(container.exists(homeworkTodosProvider), isFalse);
      expect(container.exists(courseCatalogProvider), isFalse);
      expect(container.exists(academicTimetableProvider(1)), isFalse);
      auth.signedOut();
      final empty = await container.read(campusCachedDataProvider.future);
      expect(empty.schedule, isNull);
      expect(empty.homework, isEmpty);
    },
  );
}
