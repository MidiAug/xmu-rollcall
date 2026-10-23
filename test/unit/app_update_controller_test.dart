import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import '../fixtures/update_fakes.dart';

void main() {
  final package = PackageInfo(
    appName: 'test',
    packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
    version: '0.1.1',
    buildNumber: '2',
  );
  final update = ReleaseUpdate(
    version: const AppVersion(0, 2, 0, 3),
    target: UpdateTarget.windows,
    notes: 'fixture',
    size: 100,
    sha256: '0' * 64,
  );
  late FakeUpdateService service;
  late AppUpdateController controller;
  late DateTime now;
  setUp(() {
    service = FakeUpdateService();
    now = DateTime(2026, 10, 23, 15);
    controller = AppUpdateController(
      service: service,
      package: () async => package,
      target: UpdateTarget.windows,
      now: () => now,
    );
  });
  tearDown(() {
    if (!service.closed) controller.dispose();
  });

  test(
    'launch, resume and About coalesce concurrent checks, including listener reentry',
    () async {
      service.pendingCheck = Completer<ReleaseUpdate?>();
      controller.addListener(() {
        if (controller.status == UpdateCheckStatus.checking) controller.check();
      });
      final first = controller.check();
      final second = controller.check(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(service.checks, 1);
      service.pendingCheck!.complete(update);
      await Future.wait([first, second]);
      expect(controller.update, update);
      expect(controller.status, UpdateCheckStatus.available);
    },
  );
  test(
    'automatic success checks wait six hours; explicit checks can refresh immediately',
    () async {
      await controller.check();
      now = now.add(const Duration(hours: 5));
      await controller.check();
      expect(service.checks, 1);
      await controller.check(force: true);
      expect(service.checks, 2);
      now = now.add(const Duration(hours: 6));
      await controller.check();
      expect(service.checks, 3);
      expect(controller.status, UpdateCheckStatus.current);
      expect(controller.lastCheckedAt, now);
    },
  );
  test(
    'failed check keeps a confirmed update and backs off; latest success clears it',
    () async {
      service.result = update;
      await controller.check();
      service.checkError = const UpdateException('offline');
      now = now.add(const Duration(hours: 6));
      await controller.check();
      expect(controller.update, update);
      expect(controller.status, UpdateCheckStatus.failed);
      now = now.add(const Duration(minutes: 29));
      await controller.check();
      expect(service.checks, 2);
      now = now.add(const Duration(minutes: 1));
      service.checkError = null;
      service.result = null;
      await controller.check();
      expect(service.checks, 3);
      expect(controller.update, isNull);
      expect(controller.error, isNull);
    },
  );
  test(
    'disposing cancels shared requests without publishing stale results',
    () async {
      service.pendingCheck = Completer<ReleaseUpdate?>();
      var publications = 0;
      controller.addListener(() => publications++);
      final pending = controller.check();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      expect(service.checkCancel!.isCancelled, true);
      final before = publications;
      service.pendingCheck!.complete(update);
      await pending;
      expect(publications, before);
      expect(controller.update, isNull);
    },
  );
  test('disposing during package loading prevents any network check', () async {
    controller.dispose();
    service = FakeUpdateService();
    final packageReady = Completer<PackageInfo>();
    controller = AppUpdateController(
      service: service,
      package: () => packageReady.future,
      target: UpdateTarget.windows,
    );
    final pending = controller.check();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    packageReady.complete(package);
    await pending;
    expect(service.checks, 0);
  });
}
