import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/features/update/app_update_foreground_prompt.dart';
import 'package:xmu_rollcall/features/update/app_update_section.dart';
import '../fixtures/update_fakes.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  final release = ReleaseUpdate(
    version: const AppVersion(1, 2, 3, 4),
    target: UpdateTarget.windows,
    notes: '修复',
    size: 100,
    sha256: '0' * 64,
  );
  late FakeUpdateService service;
  late FakeUpdateInstaller installer;
  late AppUpdateController controller;
  late GlobalKey<NavigatorState> navigator;
  late ProviderContainer container;
  bool busy = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeUpdateService()..result = release;
    installer = FakeUpdateInstaller();
    controller = AppUpdateController(
      service: service,
      target: UpdateTarget.windows,
      automaticDownload: true,
      package: () async => PackageInfo(
        appName: 'test',
        packageName: 'test',
        version: '1.0.0',
        buildNumber: '1',
      ),
    );
    container = ProviderContainer(
      overrides: [
        appUpdateControllerProvider.overrideWith((ref) => controller),
      ],
    );
    navigator = GlobalKey<NavigatorState>();
    busy = false;
  });
  tearDown(() {
    container.dispose();
    if (!service.closed) controller.dispose();
  });
  Future<void> mount(WidgetTester tester, {Widget? body}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppUpdateForegroundPrompt(
          navigatorKey: navigator,
          installer: installer,
          isBusy: () => busy,
          child: MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            theme: AppTheme.light(),
            home: Scaffold(body: body ?? const Text('主界面')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> foreground(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'download completion waits for next foreground and later is persisted once per version',
    (tester) async {
      service.pendingDownload = Completer<File>();
      await mount(tester);
      await controller.check();
      await tester.pump();
      expect(service.downloads, 1);
      service.pendingDownload!.complete(File('verified-installer'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.downloadStatus, UpdateDownloadStatus.ready);
      expect(controller.downloadedFile, isNotNull);
      expect(find.text('更新已下载'), findsNothing);
      await foreground(tester);
      expect(find.text('更新已下载'), findsOneWidget);
      await captureDesktopUi(tester, 'update-ready-prompt');
      expect(installer.calls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('更新已下载'), findsOneWidget);
      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();
      await foreground(tester);
      expect(find.text('更新已下载'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppUpdateForegroundPrompt.promptedVersionKey,
        ),
        release.version.full,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      // A new host must also honour the stored version; not just instance memory.
      await mount(tester);
      await foreground(tester);
      expect(find.text('更新已下载'), findsNothing);
      expect(installer.calls, 0);
    },
  );
  testWidgets(
    'busy modal and About do not consume notification; explicit install revalidates',
    (tester) async {
      service.pendingDownload = Completer<File>();
      await mount(tester);
      await controller.check();
      await tester.pump();
      service.pendingDownload!.complete(File('verified-installer'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.downloadStatus, UpdateDownloadStatus.ready);
      expect(controller.downloadedFile, isNotNull);
      busy = true;
      await foreground(tester);
      expect(find.text('更新已下载'), findsNothing);
      busy = false;
      controller.visibleUpdatePages = 1;
      await foreground(tester);
      expect(find.text('更新已下载'), findsNothing);
      controller.visibleUpdatePages = 0;
      unawaited(
        showDialog<void>(
          context: navigator.currentState!.overlay!.context,
          builder: (_) => const AlertDialog(title: Text('已有弹窗')),
        ),
      );
      await tester.pumpAndSettle();
      await foreground(tester);
      expect(find.text('更新已下载'), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await foreground(tester);
      expect(find.text('更新已下载'), findsOneWidget);
      await tester.tap(find.text('退出并安装'));
      await tester.pumpAndSettle();
      expect(service.verifications, 1);
      expect(installer.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'background download survives About unmount and the next page reuses ready package',
    (tester) async {
      service.pendingDownload = Completer<File>();
      await controller.check();
      await tester.pump();
      await mount(
        tester,
        body: AppUpdateSection(controller: controller, installer: installer),
      );
      expect(find.text('正在下载 50%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(service.downloadCancel!.isCancelled, isFalse);
      service.pendingDownload!.complete(File('verified-installer'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.downloadStatus, UpdateDownloadStatus.ready);
      await mount(
        tester,
        body: AppUpdateSection(controller: controller, installer: installer),
      );
      expect(find.byTooltip('退出并安装'), findsOneWidget);
      expect(service.downloads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('failed silent download stays quiet and manual retry succeeds', (
    tester,
  ) async {
    service.pendingDownload = Completer<File>();
    await mount(tester);
    await controller.check();
    await tester.pump();
    service.pendingDownload!.completeError(const UpdateException('offline'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(controller.downloadStatus, UpdateDownloadStatus.failed);
    await foreground(tester);
    expect(find.text('更新已下载'), findsNothing);
    expect(installer.calls, 0);
    service.pendingDownload = null;
    await controller.download();
    await tester.pump();
    expect(controller.downloadStatus, UpdateDownloadStatus.ready);
    await foreground(tester);
    expect(find.text('更新已下载'), findsOneWidget);
    service.verifyError = const UpdateException('安装包校验失败');
    await tester.tap(find.text('退出并安装'));
    await tester.pumpAndSettle();
    expect(installer.calls, 0);
    expect(controller.downloadedFile, isNull);
    AppToast.dismiss();
    await tester.pumpAndSettle();
  });
}
