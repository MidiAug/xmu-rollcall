import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_form_controls.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_providers.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_forms.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_records.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_cashier.dart';
import 'package:xmu_rollcall/features/lifestyle/life_services_page.dart';
import '../fixtures/campus_card_fixture.dart';
import '../fixtures/desktop_ui_capture.dart';

const identity = (ownerId: 1, userId: 1, assistId: null);
void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopUiCaptureFonts);
  Future<void> pump(
    WidgetTester tester,
    CampusCardFixtureClient client, {
    double width = 1104,
    bool dark = false,
    bool seed = true,
    List<Uri>? launched,
    bool launch = true,
    Map<CardElectricRoomKind, CardElectricRoom> rooms = const {},
    Widget home = const LifeServicesPage(),
  }) async {
    tester.view.physicalSize = Size(width, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      if (rooms.isNotEmpty)
        'campus_card_rooms_v1_1_1': jsonEncode({
          for (final entry in rooms.entries)
            entry.key.name: entry.value.toJson(),
        }),
      if (seed)
        campusCardCacheKey(identity): jsonEncode({
          'card': client.value.toJson(),
          'fetchedAt': DateTime.now().toIso8601String(),
        }),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browserIdentityProvider.overrideWithValue(identity),
          campusCardClientFactoryProvider.overrideWithValue(() => client),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => AcademicIdentity(
              username: '20260000000001',
              isCurrent: () async => true,
            ),
          ),
          campusCardCashierLauncherProvider.overrideWithValue((uri) async {
            launched?.add(uri);
            return launch;
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
          home: home,
        ),
      ),
    );
    if (client.pending == null || seed) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

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
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final f = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(f);
    await tester.enterText(f, value);
    await tester.pumpAndSettle();
  }

  Finder confirm(String label) => find.descendant(
    of: find.byType(AppDialogFrame),
    matching: find.widgetWithText(FilledButton, label),
  );
  for (final width in [320.0, 390.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets('native services and cached balance $width $dark', (
        tester,
      ) async {
        final client = CampusCardFixtureClient();
        await pump(tester, client, width: width, dark: dark);
        expect(find.text('¥128.50'), findsOneWidget);
        expect(client.fetchCount, 0);
        expect(find.textContaining('H5'), findsNothing);
        expect(find.text('小灵龙'), findsNothing);
        expect(find.textContaining('电量'), findsNothing);
        await captureDesktopUi(tester, 'native-card-home-$width-$dark');
        await press(tester, find.text('使用记录'));
        expect(find.byType(CampusCardRecordsPage), findsOneWidget);
        expect(client.pages, [1]);
        await captureDesktopUi(tester, 'native-card-records-$width-$dark');
        await press(tester, find.text('加载更多'));
        expect(client.pages, [1, 2]);
        expect(find.text('加载更多'), findsNothing);
        await press(tester, find.text('测试食堂16'));
        expect(find.text('交易详情'), findsOneWidget);
        expect(find.text('交易后余额'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('cold error and loading never invent a zero balance', (
    tester,
  ) async {
    final client = CampusCardFixtureClient()..fail = true;
    await pump(tester, client, seed: false);
    expect(find.text('暂时无法读取校园卡'), findsOneWidget);
    expect(find.text('¥0.00'), findsNothing);
    final loading = CampusCardFixtureClient()
      ..pending = Completer<CampusCardInfo>();
    await pump(tester, loading, seed: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('¥0.00'), findsNothing);
    loading.pending!.complete(cardFixture());
    await tester.pumpAndSettle();
    expect(find.text('¥128.50'), findsOneWidget);
  });
  for (final width in [320.0, 1104.0]) {
    testWidgets('top-up confirms exact cents and keeps one order $width', (
      tester,
    ) async {
      final client = CampusCardFixtureClient(), launched = <Uri>[];
      await pump(
        tester,
        client,
        width: width,
        launched: launched,
        launch: false,
      );
      if (width > 500) {
        expect(
          tester
              .widget<AppButton>(find.widgetWithText(AppButton, '充值'))
              .onPressed,
          isNull,
        );
        expect(find.text('请在手机端充值'), findsOneWidget);
        expect(client.writes, isEmpty);
        return;
      }
      await press(tester, find.text('充值'));
      expect(find.byType(CampusCardPaymentPage), findsOneWidget);
      await fill(tester, '金额（元）', '50.25');
      await captureDesktopUi(tester, 'native-card-topup-$width');
      await press(tester, find.widgetWithText(AppButton, '前往支付宝'));
      expect(client.writes, isEmpty);
      await press(tester, find.text('取消'));
      expect(client.writes, isEmpty);
      await press(tester, find.widgetWithText(AppButton, '前往支付宝'));
      await press(tester, confirm('前往支付宝'));
      expect(client.writes, ['recharge']);
      expect(client.cents, 5025);
      expect(launched, hasLength(1));
      await press(tester, find.text('继续支付'));
      expect(client.writes, ['recharge']);
      expect(launched, hasLength(2));
      await press(tester, find.text('付款后核对余额'));
      expect(find.byType(CampusCardPaymentPage), findsNothing);
    });
  }
  testWidgets('uncertain top-up cannot create a second order', (tester) async {
    final client = CampusCardFixtureClient()..uncertain = true;
    final launched = <Uri>[];
    await pump(tester, client, width: 390, launched: launched);
    await press(tester, find.text('充值'));
    await fill(tester, '金额（元）', '10');
    await press(tester, find.widgetWithText(AppButton, '前往支付宝'));
    await press(tester, confirm('前往支付宝'));
    expect(client.writes, ['recharge']);
    expect(launched, isEmpty);
    expect(find.text('核对账户'), findsOneWidget);
    expect(find.text('继续支付'), findsNothing);
  });
  for (final width in [320.0, 1104.0]) {
    testWidgets(
      'native electricity hierarchy checks room before payment $width',
      (tester) async {
        final client = CampusCardFixtureClient();
        await pump(tester, client, width: width);
        await press(tester, find.text('电费缴费'));
        await press(tester, find.text('园区'));
        await press(tester, find.text('思明校区'));
        await press(tester, find.text('芙蓉区'));
        await press(tester, find.text('楼栋'));
        await press(tester, find.text('测试楼'));
        await fill(tester, '房间号', '301');
        await press(tester, find.text('核对宿舍'));
        expect(find.text('缴费房间 0301'), findsOneWidget);
        expect(client.writes, isEmpty);
        await captureDesktopUi(tester, 'native-card-electricity-$width');
        if (width > 500) {
          expect(
            tester
                .widget<AppButton>(find.widgetWithText(AppButton, '填写缴费金额'))
                .onPressed,
            isNull,
          );
          expect(find.text('请在手机端缴费'), findsOneWidget);
          expect(client.writes, isEmpty);
          return;
        }
        await press(tester, find.text('填写缴费金额'));
        await fill(tester, '金额（元）', '20');
        await press(tester, find.widgetWithText(AppButton, '前往支付宝'));
        await press(tester, confirm('前往支付宝'));
        expect(client.writes, ['electricity']);
        expect(client.cents, 2000);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
  testWidgets(
    'reuse either saved room opens amount directly and allows manual editing',
    (tester) async {
      final client = CampusCardFixtureClient();
      await pump(
        tester,
        client,
        width: 390,
        rooms: {
          CardElectricRoomKind.personal: electricRoomFixture('0301'),
          CardElectricRoomKind.shared: electricRoomFixture('0300'),
        },
      );
      await press(tester, find.text('电费缴费'));
      expect(find.text('上次选择的宿舍'), findsOneWidget);
      await captureDesktopUi(tester, 'native-electricity-two-rooms');
      await press(tester, find.text('个人房间').first);
      expect(find.byType(CampusCardPaymentPage), findsOneWidget);
      expect(find.textContaining('0301'), findsOneWidget);
      expect(client.writes, isEmpty);
      await press(tester, find.text('修改宿舍'));
      expect(find.byType(CampusCardPaymentPage), findsNothing);
      await press(tester, find.text('公共客厅').first);
      expect(find.byType(CampusCardPaymentPage), findsOneWidget);
      expect(find.textContaining('0300'), findsOneWidget);
      await fill(tester, '金额（元）', '20');
      await press(tester, find.widgetWithText(AppButton, '前往支付宝'));
      expect(find.textContaining('公共客厅'), findsWidgets);
      expect(client.writes, isEmpty);
      await press(tester, find.text('取消'));
    },
  );
  testWidgets('desktop direct payment route cannot create an order', (
    tester,
  ) async {
    final client = CampusCardFixtureClient();
    await pump(
      tester,
      client,
      home: CampusCardPaymentPage(room: electricRoomFixture('0301')),
    );
    await fill(tester, '金额（元）', '20');
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, '前往支付宝'))
          .onPressed,
      isNull,
    );
    expect(find.text('请在手机端缴费'), findsOneWidget);
    expect(client.writes, isEmpty);
  });
  testWidgets(
    'directory shows card and personal electricity only, without inventing a balance',
    (tester) async {
      await pump(
        tester,
        CampusCardFixtureClient(),
        home: const Scaffold(
          body: Center(child: LifeServiceBalancesTrailing()),
        ),
      );
      expect(find.text('上次校园卡 ¥128.50'), findsOneWidget);
      expect(find.text('个人电费 —'), findsOneWidget);
      expect(find.textContaining('公共客厅'), findsNothing);
    },
  );
  testWidgets('native bills use monthly categories and transaction details', (
    tester,
  ) async {
    await pump(tester, CampusCardFixtureClient());
    await press(tester, find.text('我的账单'));
    expect(find.text('本月合计'), findsOneWidget);
    await captureDesktopUi(tester, 'native-card-bills');
    await press(tester, find.text('餐饮'));
    await press(tester, find.text('测试食堂0'));
    expect(find.text('交易详情'), findsOneWidget);
  });
  testWidgets(
    'native loss is confirmed and status comes back from the server',
    (tester) async {
      final client = CampusCardFixtureClient();
      await pump(tester, client);
      await press(tester, find.text('卡片挂失'));
      await fill(tester, '校园卡查询密码', '123456');
      await press(tester, find.widgetWithText(AppButton, '挂失校园卡'));
      await press(tester, find.text('取消'));
      expect(client.writes, isEmpty);
      await press(tester, find.widgetWithText(AppButton, '挂失校园卡'));
      await press(tester, confirm('挂失校园卡'));
      expect(client.writes, ['lost']);
      expect(find.text('已挂失'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
  testWidgets(
    'password reset only sends SMS on request and respects cooldown',
    (tester) async {
      final client = CampusCardFixtureClient();
      await pump(tester, client);
      await press(tester, find.text('修改查询密码'));
      expect(client.writes, isEmpty);
      await press(tester, find.text('发送验证码'));
      expect(client.writes, ['sms']);
      expect(find.text('120秒后重发'), findsOneWidget);
      await fill(tester, '新查询密码', '123456');
      await fill(tester, '确认新密码', '123456');
      await fill(tester, '短信验证码', '654321');
      await captureDesktopUi(tester, 'native-card-password');
      await press(tester, find.widgetWithText(AppButton, '修改密码'));
      await press(tester, confirm('修改密码'));
      expect(client.writes, ['sms', 'password']);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
