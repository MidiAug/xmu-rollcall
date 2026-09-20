import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

void main() {
  test('HomeworkItem parses end_time alias and course fields', () {
    final item = HomeworkItem.fromJson({
      'id': 42,
      'title': 'Week 3',
      'course_id': 9,
      'course_name': 'Calculus',
      'end_time': '2026-09-20T12:00:00Z',
      'type': 'homework',
      'status': 'unsubmitted',
    });
    expect(item.id, 42);
    expect(item.title, 'Week 3');
    expect(item.courseId, 9);
    expect(item.courseName, 'Calculus');
    expect(item.type, 'homework');
    expect(item.status, 'unsubmitted');
    expect(item.dueAt, isNotNull);
    expect(item.dueAt!.toUtc().year, 2026);
  });

  test('HomeworkItem prefers due_at when both present', () {
    final item = HomeworkItem.fromJson({
      'id': 1,
      'title': 'A',
      'due_at': '2026-01-01T00:00:00Z',
      'end_time': '2026-12-31T00:00:00Z',
    });
    expect(item.dueAt!.toUtc(), DateTime.utc(2026, 1, 1));
  });
}
