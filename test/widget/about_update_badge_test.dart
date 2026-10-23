import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/about_settings_row.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import '../fixtures/update_fakes.dart';

void main() {
  testWidgets(
    'About menu shows only confirmed updates and shares its check with the page',
    (tester) async {
      final package = PackageInfo(
        appName: 'test',
        packageName: 'test',
        version: '0.1.1',
        buildNumber: '2',
      );
      PackageInfo.setMockInitialValues(
        appName: 'test',
        packageName: 'test',
        version: '0.1.1',
        buildNumber: '2',
        buildSignature: '',
      );
      final service = FakeUpdateService();
      final controller = AppUpdateController(
        service: service,
        package: () async => package,
        target: UpdateTarget.windows,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AboutSettingsRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('有更新'), findsNothing);
      service.result = ReleaseUpdate(
        version: const AppVersion(0, 2, 0, 3),
        target: UpdateTarget.windows,
        notes: 'fixture',
        size: 100,
        sha256: '0' * 64,
      );
      await controller.check();
      await tester.pumpAndSettle();
      expect(find.text('有更新'), findsOneWidget);
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();
      expect(find.text('有更新 · v0.2.0'), findsOneWidget);
      expect(service.checks, 1);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('有更新'), findsOneWidget);
      service.checkError = const UpdateException('offline');
      await controller.check(force: true);
      await tester.pumpAndSettle();
      expect(find.text('有更新'), findsOneWidget);
      service.checkError = null;
      service.result = null;
      await controller.check(force: true);
      await tester.pumpAndSettle();
      expect(find.text('有更新'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
