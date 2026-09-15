import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

void main() {
  CourseRollcallRecord row({
    required String id,
    String course = '课',
    String status = '已签到',
    String type = '数字',
  }) {
    return CourseRollcallRecord(
      courseId: 'c1',
      courseTitle: course,
      rollcallId: id,
      rollcallTime: DateTime.utc(2026, 9, 11, 10),
      typeLabel: type,
      signedStatus: status,
      platformStatus: status,
    );
  }

  test('unchanged refresh returns same list instance', () {
    final prev = [row(id: '1'), row(id: '2')];
    final next = [row(id: '1'), row(id: '2')];
    final merged = mergeCourseHistory(prev, next);
    expect(identical(merged, prev), isTrue);
  });

  test('new row is inserted; unchanged rows keep identity', () {
    final a = row(id: '1');
    final b = row(id: '2');
    final prev = [a, b];
    final neu = row(id: '3');
    final merged = mergeCourseHistory(prev, [neu, row(id: '1'), row(id: '2')]);
    expect(merged.length, 3);
    expect(identical(merged[1], a), isTrue);
    expect(identical(merged[2], b), isTrue);
    expect(merged[0].rollcallId, '3');
  });

  test('status change replaces that row only', () {
    final a = row(id: '1', status: '未签到');
    final prev = [a];
    final merged = mergeCourseHistory(prev, [row(id: '1', status: '已签到')]);
    expect(merged.length, 1);
    expect(identical(merged[0], a), isFalse);
    expect(merged[0].signedStatus, '已签到');
  });
}
