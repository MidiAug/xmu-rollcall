import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

void main() {
  RollcallItem item({
    required int id,
    String title = '课',
    String status = 'on_call_absence',
    String? code,
  }) {
    return RollcallItem(
      rollcallId: id,
      courseTitle: title,
      createdByName: '老师',
      type: RollcallType.number,
      status: status,
      rollcallStatus: 'on',
      isExpired: false,
      scored: false,
      numberCode: code,
    );
  }

  test('unchanged refresh returns same list instance', () {
    final prev = [item(id: 1, code: '12'), item(id: 2)];
    final next = [item(id: 1, code: '12'), item(id: 2)];
    final merged = mergeActiveRollcalls(prev, next);
    expect(identical(merged, prev), isTrue);
  });

  test('new row is inserted; unchanged rows keep identity', () {
    final a = item(id: 1);
    final b = item(id: 2);
    final prev = [a, b];
    final neu = item(id: 3);
    final merged = mergeActiveRollcalls(prev, [neu, item(id: 1), item(id: 2)]);
    expect(merged.length, 3);
    expect(identical(merged[1], a), isTrue);
    expect(identical(merged[2], b), isTrue);
    expect(merged[0].rollcallId, 3);
  });

  test('status or code change replaces that row only', () {
    final a = item(id: 1, status: 'on_call_absence', code: null);
    final prev = [a];
    final merged = mergeActiveRollcalls(
      prev,
      [item(id: 1, status: 'on_call_fine', code: '88')],
    );
    expect(merged.length, 1);
    expect(identical(merged[0], a), isFalse);
    expect(merged[0].isAnswered, isTrue);
    expect(merged[0].numberCode, '88');
  });
}
