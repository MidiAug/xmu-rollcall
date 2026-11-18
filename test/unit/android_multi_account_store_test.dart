import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/platform/android_monitor_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const owner = AndroidMonitorRun(
    id: 'owner-run',
    userId: 1,
    config: MonitorConfig(autoAnswer: true),
  );
  const assist = AndroidMonitorRun(
    id: 'assist-run',
    userId: 2,
    ownerUserId: 1,
    assistUserId: 2,
    config: MonitorConfig(),
  );

  test(
    'both Android runs retain isolated rules and revoking one preserves the other',
    () async {
      await AndroidMonitorStore.writeRun(owner);
      await AndroidMonitorStore.writeRun(assist);
      expect((await AndroidMonitorStore.readRuns()).map((r) => r.id), [
        'owner-run',
        'assist-run',
      ]);
      expect(
        (await AndroidMonitorStore.readRun(runId: owner.id))!.config.autoAnswer,
        isTrue,
      );
      expect(
        (await AndroidMonitorStore.readRun(
          runId: assist.id,
        ))!.config.autoAnswer,
        isFalse,
      );
      await AndroidMonitorStore.clearRun(runId: assist.id);
      await expectLater(AndroidMonitorStore.writeRun(assist), throwsStateError);
      expect(await AndroidMonitorStore.readRun(runId: assist.id), isNull);
      expect((await AndroidMonitorStore.readRuns()).single.id, owner.id);
      await AndroidMonitorStore.clearRun();
      expect(await AndroidMonitorStore.readRuns(), isEmpty);
    },
  );

  test(
    'migrates a legacy background task without losing its authorization',
    () async {
      await FlutterForegroundTask.saveData(
        key: 'monitor_run_v2',
        value: jsonEncode(owner.toJson()),
      );
      expect((await AndroidMonitorStore.readRuns()).single.id, owner.id);
      await AndroidMonitorStore.writeRun(assist);
      expect((await AndroidMonitorStore.readRuns()).length, 2);
      await AndroidMonitorStore.clearRun(runId: owner.id);
      expect((await AndroidMonitorStore.readRuns()).single.id, assist.id);
    },
  );

  test(
    'snapshots and notification IDs remain separate for each account',
    () async {
      for (final run in [owner, assist]) {
        await AndroidMonitorStore.writeSnapshot({
          'runId': run.id,
          'userId': run.userId,
          'ownerUserId': run.ownerUserId,
          'assistUserId': run.assistUserId,
          'running': true,
        });
      }
      expect(
        (await AndroidMonitorStore.readSnapshot(runId: owner.id))!['userId'],
        1,
      );
      expect(
        (await AndroidMonitorStore.readAccountSnapshot(1, 2))!['userId'],
        2,
      );
      expect(
        AndroidMonitorNotifications.notificationId(owner.id),
        isNot(AndroidMonitorNotifications.notificationId(assist.id)),
      );
    },
  );
}
