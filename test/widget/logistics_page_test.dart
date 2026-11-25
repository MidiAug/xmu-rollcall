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
import 'package:xmu_rollcall/features/logistics/logistics_forms.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_form_controls.dart';
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
    expect(find.text('测试账号'), findsNothing);
    await captureDesktopUi(tester, 'logistics-one-order');
  });
  testWidgets('all primary actions stay inside native forms', (tester) async {
    final launched = <Uri>[];
    await pump(tester, total: 0, launched: launched);
    expect(find.text('暂无报修记录'), findsOneWidget);
    await tester.tap(find.text('我要报修'));
    await tester.pumpAndSettle();
    expect(find.byType(LogisticsRepairForm), findsOneWidget);
    expect(find.text('故障描述'), findsOneWidget);
    await captureDesktopUi(tester, 'logistics-repair-form');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('意见反馈'));
    await tester.pumpAndSettle();
    expect(find.byType(LogisticsFeedbackForm), findsOneWidget);
    await captureDesktopUi(tester, 'logistics-feedback-form');
    expect(launched, isEmpty);
  });
  testWidgets('network failure retains native retry without website fallback', (
    tester,
  ) async {
    await pump(
      tester,
      seed: false,
      client: LogisticsFixtureClient()..fail = true,
    );
    expect(find.text('暂时无法读取后勤数据'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.textContaining('官方'), findsNothing);
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
  Future<void> press(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        maxScrolls: 30,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  Finder confirm(String label) => find.descendant(
    of: find.byType(AppDialogFrame),
    matching: find.widgetWithText(FilledButton, label),
  );
  for (final width in [320.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native repair validates, cancels confirmation and submits once $width $dark',
        (tester) async {
          final client = LogisticsFixtureClient(total: 0);
          await pump(
            tester,
            width: width,
            dark: dark,
            client: client,
            total: 0,
          );
          await press(tester, find.text('我要报修'));
          await press(tester, find.widgetWithText(AppButton, '提交报修'));
          expect(client.writes, isEmpty);
          await press(tester, find.text('故障区域'));
          await press(tester, find.text('翔安校区'));
          await press(tester, find.text('测试楼'));
          await press(tester, find.text('维修项目'));
          await press(tester, find.text('水'));
          await press(tester, find.text('管道维修'));
          await fill(tester, '详细地址', '101室');
          expect(find.widgetWithText(TextFormField, '报修人'), findsNothing);
          await press(tester, find.text('联系信息'));
          await fill(tester, '报修人', '测试用户');
          await fill(tester, '联系电话', '13800000000');
          await fill(tester, '故障描述', '管道堵塞，请检查');
          await captureDesktopUi(tester, 'native-repair-filled-$width-$dark');
          await press(tester, find.widgetWithText(AppButton, '提交报修'));
          expect(find.text('提交报修？'), findsOneWidget);
          await press(tester, find.text('取消'));
          expect(client.writes, isEmpty);
          await press(tester, find.widgetWithText(AppButton, '提交报修'));
          await press(tester, confirm('提交报修'));
          expect(client.writes, ['repair']);
          expect(client.lastForm!['areaId'], 'building');
          expect(client.lastForm!['ifPublish'], '1');
          expect(find.byType(LogisticsRepairForm), findsNothing);
          await press(tester, find.text('我要报修'));
          expect(find.text('上次报修地点'), findsOneWidget);
          final addressField = find.widgetWithText(TextFormField, '详细地址');
          expect(
            tester.widget<TextFormField>(addressField).controller!.text,
            isEmpty,
          );
          await captureDesktopUi(tester, 'logistics-reuse-place-$width-$dark');
          await press(tester, find.text('上次报修地点'));
          expect(
            tester.widget<TextFormField>(addressField).controller!.text,
            '101室',
          );
          expect(find.text('翔安校区 / 测试楼'), findsOneWidget);
          // Reusing the location never reuses the previous fault or project.
          expect(
            tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, '故障描述'),
                )
                .controller!
                .text,
            isEmpty,
          );
          expect(find.text('选择维修项目'), findsOneWidget);
        },
      );
      testWidgets(
        'native feedback preserves type scope and confirmation $width $dark',
        (tester) async {
          final client = LogisticsFixtureClient(total: 0);
          await pump(
            tester,
            width: width,
            dark: dark,
            total: 0,
            client: client,
          );
          await press(tester, find.text('意见反馈'));
          await press(tester, find.text('建议'));
          await press(tester, find.text('服务类型'));
          await press(tester, find.text('测试服务部'));
          await press(tester, find.text('公寓服务'));
          await fill(tester, '标题', '公寓服务建议');
          await fill(tester, '详细说明', '请改善服务');
          await fill(tester, '联系方式', '13800000000');
          await captureDesktopUi(tester, 'native-feedback-filled-$width-$dark');
          await press(tester, find.widgetWithText(AppButton, '提交反馈'));
          expect(client.writes, isEmpty);
          await press(tester, confirm('提交建议'));
          expect(client.writes, ['feedback']);
          expect(client.lastForm!['serverType'], 1);
          expect(client.lastForm!['projectName'], ['unit', 'service']);
          expect(client.lastForm!['serviceScopeName'], '公寓服务');
        },
      );
    }
  }
  testWidgets(
    'native evaluation warns before low scores and does not auto submit',
    (tester) async {
      final client = LogisticsFixtureClient();
      await pump(tester, client: client);
      await press(tester, find.byKey(const ValueKey('repair-fixture-0')));
      await press(tester, find.widgetWithText(AppButton, '评价维修'));
      for (final name in ['服务态度', '服务质量', '维修质量', '维修速度']) {
        await press(tester, find.byTooltip('$name 1星'));
      }
      await captureDesktopUi(tester, 'native-evaluation');
      await press(tester, find.widgetWithText(AppButton, '提交评价'));
      expect(find.textContaining('触发返修'), findsOneWidget);
      expect(client.writes, isEmpty);
      await press(tester, find.text('取消'));
      expect(client.writes, isEmpty);
    },
  );
  testWidgets(
    'native feedback detail reads replies and deletion keeps a deleted record',
    (tester) async {
      final client = LogisticsFixtureClient();
      await pump(tester, client: client);
      await press(tester, find.text('我的反馈'));
      await press(tester, find.text('测试服务反馈'));
      expect(find.text('我们已经收到建议'), findsOneWidget);
      await press(tester, find.widgetWithText(AppButton, '删除反馈'));
      await tester.enterText(find.byType(TextField).last, '测试删除');
      await tester.pump();
      await press(tester, confirm('删除反馈'));
      expect(client.writes, ['delete']);
      expect(find.text('已删除'), findsOneWidget);
    },
  );
  testWidgets('native messages can be read without navigating to a website', (
    tester,
  ) async {
    final client = LogisticsFixtureClient();
    final launched = <Uri>[];
    await pump(tester, client: client, launched: launched);
    await press(tester, find.text('全部消息'));
    await press(tester, find.text('报修服务进度提醒'));
    await press(tester, find.widgetWithText(AppButton, '标为已读'));
    expect(client.writes, ['read']);
    expect(find.text('已读'), findsOneWidget);
    expect(launched, isEmpty);
  });
}
