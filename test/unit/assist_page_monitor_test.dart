import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/assist/assist_rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  test('AssistPageMonitor stops when list becomes non-empty', () async {
    var refreshCount = 0;
    var list = <RollcallItem>[];
    var changed = 0;

    final monitor = AssistPageMonitor(
      refresh: () async {
        refreshCount++;
        if (refreshCount >= 1) {
          list = [
            RollcallItem.fromJson({
              'rollcall_id': 1,
              'course_title': 'C',
              'created_by_name': 'T',
              'is_number': true,
              'status': 'on_call',
              'rollcall_status': 'start',
              'is_expired': false,
              'scored': false,
            }),
          ];
        }
      },
      readList: () => list,
      readConfig: () => const MonitorConfig(intervalSeconds: 15, jitterRatio: 0),
      onChanged: () => changed++,
    );

    monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(refreshCount, greaterThanOrEqualTo(1));
    expect(monitor.running, isFalse);
    monitor.dispose();
  });
}
