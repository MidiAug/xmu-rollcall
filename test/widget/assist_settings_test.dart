import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/features/update/update_download_route_selector.dart';
import '../fixtures/update_fakes.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

class _TestAuthController extends AuthController {
  _TestAuthController()
    : super(
        AuthRepository(
          http: TronHttpClient(store: SecureStore.memory()),
          store: SecureStore.memory(),
        ),
      );

  @override
  Future<void> bootstrap() async {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesktopPreviewFonts);

  testWidgets('assist section shows import export without master switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final memory = SecureStore.memory();

    // Tall surface so ListView builds sections below the fold (课程与缓存).
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(memory),
          deviceIdentityProvider.overrideWith((ref) => DeviceIdentity(memory)),
          sessionClientRegistryProvider.overrideWith(
            (ref) => SessionClientRegistry(
              store: memory,
              createClient:
                  ({
                    required store,
                    required sessionKey,
                    required rateLimiter,
                  }) {
                    return TronHttpClient(
                      store: store,
                      sessionKey: sessionKey,
                      rateLimiter: rateLimiter,
                      cookieJar: CookieJar(),
                    );
                  },
            ),
          ),
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          appUpdateControllerProvider.overrideWith(
            (ref) => AppUpdateController(
              service: FakeUpdateService(),
              package: PackageInfo.fromPlatform,
              target: UpdateTarget.windows,
            ),
          ),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(ready: true),
              bootstrap: false,
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: child!,
          ),
          theme: AppTheme.dark(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UpdateDownloadRouteSelector), findsNothing);

    PackageInfo.setMockInitialValues(
      appName: '厦大签到',
      packageName: 'test',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    expect(find.text('关于'), findsOneWidget);
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    expect(find.text('版本 0.1.0'), findsOneWidget);
    final routeRow = find.ancestor(
      of: find.text('下载线路'),
      matching: find.byType(SettingsRow),
    );
    final row = tester.widget<SettingsRow>(routeRow);
    expect(row.trailing, isA<UpdateDownloadRouteSelector>());
    expect(row.subtitleWidget, isNull);
    expect(
      tester.getCenter(find.byKey(const ValueKey('update-route-select'))).dx,
      greaterThan(tester.getCenter(find.text('下载线路')).dx),
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    // Import/export now live on the dedicated assist settings subpage.
    expect(find.text('协助同学'), findsOneWidget);
    await tester.tap(find.text('协助同学'));
    await tester.pumpAndSettle();
    expect(find.text('启用协助'), findsNothing);
    expect(find.text('导出协助码'), findsOneWidget);
    expect(find.text('导入协助身份'), findsOneWidget);
    final importedRow = find.ancestor(
      of: find.text('已导入名单'),
      matching: find.byType(SettingsRow),
    );
    expect(tester.widget<SettingsRow>(importedRow).subtitle, isNull);
    final count = find.descendant(of: importedRow, matching: find.text('0 人'));
    expect(count, findsOneWidget);
    expect(
      tester.getRect(count).left,
      greaterThan(tester.getRect(find.text('已导入名单')).right),
    );
    expect(
      tester.getCenter(count).dy,
      closeTo(tester.getCenter(find.text('已导入名单')).dy, 1),
    );
    expect(find.byType(Switch), findsNothing);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpAndSettle();
    await captureDesktopUi(tester, 'state-audit-assist-signed-out');
    final export = tester.getSemantics(find.text('导出协助码'));
    expect(export.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(export.flagsCollection.isButton, isTrue);
  });

  Widget settingsScope({
    required Widget child,
    required TargetPlatform platform,
    GlobalKey? captureKey,
  }) {
    final memory = SecureStore.memory();
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(platform: platform),
      builder: (context, inner) => AppDensityScope(child: inner!),
      home: child,
    );
    return ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(memory),
        deviceIdentityProvider.overrideWith((ref) => DeviceIdentity(memory)),
        sessionClientRegistryProvider.overrideWith(
          (ref) => SessionClientRegistry(
            store: memory,
            createClient:
                ({required store, required sessionKey, required rateLimiter}) {
                  return TronHttpClient(
                    store: store,
                    sessionKey: sessionKey,
                    rateLimiter: rateLimiter,
                    cookieJar: CookieJar(),
                  );
                },
          ),
        ),
        authControllerProvider.overrideWith((ref) => _TestAuthController()),
        appUpdateControllerProvider.overrideWith(
          (ref) => AppUpdateController(
            service: FakeUpdateService(),
            package: PackageInfo.fromPlatform,
            target: platform == TargetPlatform.android
                ? UpdateTarget.android
                : UpdateTarget.windows,
          ),
        ),
        assistControllerProvider.overrideWith(
          (ref) => AssistController(
            ref,
            initial: const AssistUiState(ready: true),
            bootstrap: false,
          ),
        ),
      ],
      child: captureKey == null
          ? app
          : RepaintBoundary(key: captureKey, child: app),
    );
  }

  Future<void> captureAssistUi(
    WidgetTester tester,
    GlobalKey key,
    String name,
  ) async {
    expect(tester.takeException(), isNull);
    if (Platform.environment['CAPTURE_SETTINGS_UI'] != '1') return;
    await tester.runAsync(() async {
      final dir = await Directory(
        '.tools/settings-polish',
      ).create(recursive: true);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${dir.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final spec in [
    (
      name: 'assist-desktop-960',
      size: const Size(960, 720),
      platform: TargetPlatform.windows,
    ),
    (
      name: 'assist-mobile-384',
      size: const Size(384, 844),
      platform: TargetPlatform.android,
    ),
  ]) {
    testWidgets(
      'SettingsAssistPage renders 32px symbols, 16px glyphs and aligned divider (${spec.name})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = spec.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final key = GlobalKey();
        await tester.pumpWidget(
          settingsScope(
            platform: spec.platform,
            captureKey: key,
            child: const Scaffold(body: SettingsAssistPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppServiceSymbol), findsNWidgets(3));
        for (final entry in const [
          (title: '导出协助码', kind: AppSettingsGlyphKind.link),
          (title: '导入协助身份', kind: AppSettingsGlyphKind.trayDown),
          (title: '已导入名单', kind: AppSettingsGlyphKind.user),
        ]) {
          final rowFinder = find.ancestor(
            of: find.text(entry.title),
            matching: find.byType(SettingsRow),
          );
          final symbolFinder = find.descendant(
            of: rowFinder,
            matching: find.byType(AppServiceSymbol),
          );
          final glyphFinder = find.descendant(
            of: symbolFinder,
            matching: find.byType(AppSettingsGlyph),
          );

          expect(symbolFinder, findsOneWidget);
          expect(glyphFinder, findsOneWidget);
          final symbol = tester.widget<AppServiceSymbol>(symbolFinder);
          final glyph = tester.widget<AppSettingsGlyph>(glyphFinder);
          expect(symbol.size, 32);
          expect(tester.getSize(symbolFinder), const Size(32, 32));
          expect(glyph.kind, entry.kind);
          expect(glyph.size, 16);
          expect(tester.getSize(glyphFinder), const Size(16, 16));
          expect(IconTheme.of(tester.element(glyphFinder)).size, 16);
        }

        final sectionFinder = find.byType(SettingsSection);
        expect(sectionFinder, findsOneWidget);
        final section = tester.widget<SettingsSection>(sectionFinder);
        final sectionContext = tester.element(sectionFinder);
        expect(
          section.dividerIndent,
          AppDensity.rowPadding(sectionContext).left +
              32 +
              AppDensity.settingsInnerGap,
        );

        await captureAssistUi(tester, key, spec.name);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('desktop SettingsPage renders AppSettingsGlyph for main rows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      settingsScope(
        platform: TargetPlatform.windows,
        child: const Scaffold(body: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );

    for (final entry in const [
      (title: '外观', kind: AppSettingsGlyphKind.sun),
      (title: '常用网站打开方式', kind: AppSettingsGlyphKind.globe),
      (title: '关闭窗口时', kind: AppSettingsGlyphKind.window),
      (title: '地点管理', kind: AppSettingsGlyphKind.mapPin),
      (title: '协助同学', kind: AppSettingsGlyphKind.user),
      (title: '开机启动', kind: AppSettingsGlyphKind.power),
      (title: '启动后继续值守', kind: AppSettingsGlyphKind.shieldCheck),
      (title: '桌面提醒', kind: AppSettingsGlyphKind.bell),
      (title: '数据与诊断', kind: AppSettingsGlyphKind.database),
      (title: '关于', kind: AppSettingsGlyphKind.info),
    ]) {
      await tester.scrollUntilVisible(
        find.text(entry.title),
        180,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      final rowFinder = find.ancestor(
        of: find.text(entry.title),
        matching: find.byType(SettingsRow),
      );
      final glyphFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(AppSettingsGlyph),
      );
      expect(glyphFinder, findsOneWidget, reason: '${entry.title} glyph');
      expect(
        tester.widget<AppSettingsGlyph>(glyphFinder).kind,
        entry.kind,
        reason: '${entry.title} glyph kind',
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
