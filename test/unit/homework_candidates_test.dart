import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/homework/homework_candidates.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);
  CatalogCourse course(int weekday) => CatalogCourse(
    id: '1',
    title: 'Course',
    timetables: {
      weekday: [
        TimetableSlot(
          sequence: 1,
          start: DateTime(2000, 1, 3, 8),
          end: DateTime(2000, 1, 3, 9),
        ),
      ],
    },
  );
  DiskCacheSnapshot disk(
    DateTime fetched, {
    List<HomeworkItem> items = const [],
  }) => DiskCacheSnapshot(
    fetchedAt: fetched,
    items: items.map((i) => i.toJson()).toList(),
  );
  test('cold miss is queried; age alone never scans a warm course', () {
    expect(
      homeworkRefreshReason(disk: null, course: course(5), todos: [], now: now),
      'never_checked',
    );
    expect(
      homeworkRefreshReason(
        disk: disk(DateTime(2026, 10, 20, 12)),
        course: course(5),
        todos: [],
        now: now,
      ),
      isNull,
    );
  });
  test(
    'class end causes one refresh, not repeated refreshes after the same class',
    () {
      expect(
        homeworkRefreshReason(
          disk: disk(DateTime(2026, 10, 22, 8)),
          course: course(4),
          todos: [],
          now: now,
        ),
        'period_ended',
      );
      expect(
        homeworkRefreshReason(
          disk: disk(DateTime(2026, 10, 22, 9, 1)),
          course: course(4),
          todos: [],
          now: now,
        ),
        isNull,
      );
    },
  );
  test('crossing deadline causes one refresh even inside a normal TTL', () {
    final item = HomeworkItem(id: 1, title: 'Task', courseId: 1, dueAt: now);
    expect(
      homeworkRefreshReason(
        disk: disk(now.subtract(const Duration(minutes: 1)), items: [item]),
        course: course(5),
        todos: [],
        now: now,
      ),
      'deadline_passed',
    );
    expect(
      homeworkRefreshReason(
        disk: disk(now.add(const Duration(minutes: 1)), items: [item]),
        course: course(5),
        todos: [],
        now: now.add(const Duration(hours: 1)),
      ),
      isNull,
    );
  });
  test(
    'new or changed homework is a signal; quizzes and other courses are not',
    () {
      final snap = disk(
        now,
        items: [const HomeworkItem(id: 1, title: 'Old', courseId: 1)],
      );
      String? reason(List<HomeworkItem> todos) => homeworkRefreshReason(
        disk: snap,
        course: course(5),
        todos: todos,
        now: now,
      );
      expect(
        reason([const HomeworkItem(id: 1, title: 'Old', courseId: 1)]),
        isNull,
      );
      expect(
        reason([const HomeworkItem(id: 1, title: 'Renamed', courseId: 1)]),
        'todo_changed',
      );
      expect(
        reason([const HomeworkItem(id: 2, title: 'New', courseId: 1)]),
        'todo_changed',
      );
      expect(
        reason([
          const HomeworkItem(id: 2, title: 'Quiz', courseId: 1, type: 'exam'),
        ]),
        isNull,
      );
      expect(
        reason([const HomeworkItem(id: 2, title: 'Other', courseId: 2)]),
        isNull,
      );
    },
  );
}
