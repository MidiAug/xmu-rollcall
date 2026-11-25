import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/browser/browser_preferences.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/logistics/logistics_page.dart';
import 'package:xmu_rollcall/features/logistics/logistics_provider.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/logistics_fixture.dart';

const identity = (ownerId: 1, userId: 1, assistId: null);
void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopUiCaptureFonts);
  Future<void> pump(
    WidgetTester tester, {
    double width = 1104,
    bool dark = false,
    int total = 1,
    bool directory = false,
    LogisticsFixtureClient? client,
    bool seed = true,
    List<Uri>? launched,
  }) async {
    tester.view.physicalSize = Size(width, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = LogisticsSnapshot(
      repairs: [
        for (var i = 0; i < total && i < 20; i++)
          LogisticsRepair(logisticsRepairFixture(i)),
      ],
      messages: [
        if (total > 0)
          LogisticsMessage({
            'title': '报修服务进度提醒',
            'content': '您的单据已完工，请及时评价！',
            'sendTime': '2026-11-12 17:59',
            'status': 0,
          }),
      ],
      total: total,
      page: 1,
      fetchedAt: DateTime.now(),
    );
    SharedPreferences.setMockInitialValues({
      WebsiteOpenModeController.key: WebsiteOpenMode.systemBrowser.name,
      if (seed) logisticsCacheKey(identity): jsonEncode(snapshot.toJson()),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browserIdentityProvider.overrideWithValue(identity),
          rollcallAccountNameProvider.overrideWithValue('测试账号'),
          currentTeachingCoursesProvider.overrideWith((ref) async => []),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => AcademicIdentity(
              username: 'fixture',
              isCurrent: () async => true,
            ),
          ),
          logisticsClientFactoryProvider.overrideWithValue(
            () => client ?? LogisticsFixtureClient(total: total),
          ),
          websiteExternalLauncherProvider.overrideWithValue((uri) async {
            launched?.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: desktopCaptureTheme(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: width < 500
                  ? TargetPlatform.android
                  : TargetPlatform.windows,
            ),
          ),
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.3 : 1)),
              child: child!,
            ),
          ),
          home: directory
              ? const Scaffold(body: CampusToolsPage())
              : const LogisticsPage(),
        ),
      ),
    );
    if (client?.pending == null) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  for (final width in [320.0, 390.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets('native logistics and detail $width $dark', (tester) async {
        await pump(tester, width: width, dark: dark, total: 21);
        expect(find.text('待评价'), findsWidgets);
        await captureDesktopUi(tester, 'logistics-$width-$dark');
        await tester.tap(find.byKey(const ValueKey('repair-fixture-0')));
        await tester.pumpAndSettle();
        expect(find.byType(LogisticsRepairPage), findsOneWidget);
        expect(find.text('工单进度'), findsOneWidget);
        await captureDesktopUi(tester, 'logistics-detail-$width-$dark');
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(LogisticsRepairPage), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('tool directory opens the real logistics module', (tester) async {
    await pump(tester, directory: true);
    final tile = find.byKey(const ValueKey('tool-logistics'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(LogisticsPage), findsOneWidget);
    expect(find.text('我的报修'), findsOneWidget);
    await captureDesktopUi(tester, 'logistics-one-order');
  });
  testWidgets(
    'empty result and official actions preserve URLs without credentials',
    (tester) async {
      final launched = <Uri>[];
      await pump(tester, total: 0, launched: launched);
      expect(find.text('暂无报修记录'), findsOneWidget);
      expect(find.text('暂无后勤消息'), findsOneWidget);
      await tester.tap(find.text('我要报修'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('意见反馈'));
      await tester.pumpAndSettle();
      expect(launched, [
        logisticsWebsite('repairCatalogue'),
        logisticsWebsite('service/catalogue'),
      ]);
      await captureDesktopUi(tester, 'logistics-empty');
    },
  );
  testWidgets('network failure keeps official recovery available', (
    tester,
  ) async {
    final launched = <Uri>[];
    await pump(
      tester,
      seed: false,
      client: LogisticsFixtureClient()..fail = true,
      launched: launched,
    );
    expect(find.text('暂时无法读取后勤数据'), findsOneWidget);
    await tester.tap(find.text('打开官方报修'));
    await tester.pumpAndSettle();
    expect(launched.single, logisticsWebsite('myRepairList'));
    await captureDesktopUi(tester, 'logistics-error');
  });
  testWidgets('cold loading does not invent zero orders', (tester) async {
    final client = LogisticsFixtureClient()..pending = Completer<void>();
    await pump(tester, seed: false, client: client);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('暂无报修记录'), findsNothing);
    client.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('待评价'), findsOneWidget);
  });
}
