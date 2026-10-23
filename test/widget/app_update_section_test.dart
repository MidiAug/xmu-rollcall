import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_section.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';
import '../fixtures/update_fakes.dart';

void main() {
  final package = PackageInfo(
    appName: 'test',
    packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
    version: '0.1.1',
    buildNumber: '2',
  );
  ReleaseUpdate update(UpdateTarget target) => ReleaseUpdate(
    version: const AppVersion(0, 2, 0, 3),
    target: target,
    notes: 'A synthetic change\nAnother change',
    size: 1024 * 1024,
    sha256: '0' * 64,
  );
  late FakeUpdateService service;
  late FakeUpdateInstaller installer;
  setUp(() {
    service = FakeUpdateService();
    installer = FakeUpdateInstaller();
  });
  Future<void> mount(
    WidgetTester tester, {
    UpdateTarget target = UpdateTarget.windows,
    PackageInfo? info,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              AppUpdateSection(
                package: Future.value(info ?? package),
                service: service,
                installer: installer,
                target: target,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [384.0, 960.0]) {
    testWidgets(
      'update at $width shows notes, verifies and requires installation confirmation',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        service.result = update(UpdateTarget.windows);
        await mount(tester);
        expect(service.checks, 1);
        expect(find.text('有更新 · v0.2.0'), findsOneWidget);
        await tester.tap(find.text('有更新 · v0.2.0'));
        await tester.pumpAndSettle();
        expect(find.textContaining('A synthetic change'), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('下载更新'));
        await tester.pumpAndSettle();
        expect(find.text('下载完成，安装包校验通过'), findsOneWidget);
        expect(installer.calls, 0);
        await tester.tap(find.byTooltip('退出并安装'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(installer.calls, 0);
        await tester.tap(find.byTooltip('退出并安装'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '退出并安装').last);
        await tester.pumpAndSettle();
        expect(service.verifications, 1);
        expect(installer.calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 960.0]) {
    testWidgets(
      'check changes status and right action inside the same row at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester);
        final initial = tester.getRect(find.byType(SettingsRow));
        expect(find.text('已是最新版本'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        service.pendingCheck = Completer<ReleaseUpdate?>();
        await tester.tap(find.byTooltip('检查更新'));
        await tester.pump();
        expect(find.text('正在检查新版本'), findsOneWidget);
        expect(find.byType(SettingsRow), findsOneWidget);
        service.pendingCheck!.complete(update(UpdateTarget.windows));
        await tester.pumpAndSettle();
        expect(find.text('有更新 · v0.2.0'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
        expect(find.byTooltip('下载更新'), findsOneWidget);
        expect(find.byType(SettingsRow), findsOneWidget);
        expect(find.textContaining('A synthetic change'), findsNothing);
        if (width == 960) {
          expect(tester.getRect(find.byType(SettingsRow)), initial);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'failure is retryable and an up-to-date check has no install action',
    (tester) async {
      service.checkError = const UpdateException('GitHub 暂时不可用');
      await mount(tester);
      expect(find.text('暂时无法检查'), findsOneWidget);
      expect(find.byTooltip('GitHub 暂时不可用'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      service.checkError = null;
      await tester.tap(find.byTooltip('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('已是最新版本'), findsOneWidget);
      expect(find.text('下载更新'), findsNothing);
      expect(service.checks, 2);
    },
  );
  testWidgets('download cancellation can retry; leaving cancels pending work', (
    tester,
  ) async {
    service.result = update(UpdateTarget.windows);
    service.pendingDownload = Completer<File>();
    await mount(tester);
    await tester.tap(find.byTooltip('下载更新'));
    await tester.pumpAndSettle();
    expect(find.text('正在下载 50%'), findsOneWidget);
    await tester.tap(find.byTooltip('取消下载'));
    await tester.pumpAndSettle();
    expect(service.downloadCancel!.isCancelled, true);
    expect(find.text('下载已取消，可重新下载'), findsOneWidget);
    await tester.tap(find.byTooltip('下载更新'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(service.closed, true);
    expect(service.downloadCancel!.isCancelled, true);
    service.pendingDownload!.complete(File('fixture'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Android permission round trip retains download and rechecks before retry',
    (tester) async {
      service.result = update(UpdateTarget.android);
      installer.result = InstallLaunch.permissionRequired;
      await mount(tester, target: UpdateTarget.android);
      await tester.tap(find.byTooltip('下载更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('安装更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开安装器'));
      await tester.pumpAndSettle();
      expect(find.textContaining('允许此来源安装后'), findsOneWidget);
      expect(service.downloads, 1);
      installer.result = InstallLaunch.launched;
      await tester.tap(find.byTooltip('安装更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开安装器'));
      await tester.pumpAndSettle();
      expect(installer.calls, 2);
      expect(service.verifications, 2);
      expect(service.downloads, 1);
    },
  );
  testWidgets(
    'changed cached installer cannot launch and offers a fresh download',
    (tester) async {
      service.result = update(UpdateTarget.windows);
      await mount(tester);
      await tester.tap(find.byTooltip('下载更新'));
      await tester.pumpAndSettle();
      service.verifyError = const UpdateException('安装包校验失败，请重新下载');
      await tester.tap(find.byTooltip('退出并安装'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '退出并安装').last);
      await tester.pumpAndSettle();
      expect(installer.calls, 0);
      expect(find.byTooltip('重新下载'), findsOneWidget);
    },
  );
  testWidgets('preview builds do not download production APKs', (tester) async {
    await mount(
      tester,
      target: UpdateTarget.android,
      info: PackageInfo(
        appName: 'test',
        packageName: '${package.packageName}.preview',
        version: '0.1.1-preview',
        buildNumber: '2',
      ),
    );
    expect(find.text('暂时无法检查'), findsOneWidget);
    expect(find.byTooltip('测试版与正式版独立安装，请从发布页获取正式版'), findsOneWidget);
    expect(service.checks, 0);
  });
}
