import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';

import '../fixtures/update_fakes.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repository()) {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

ThemeData _theme(Brightness brightness, TargetPlatform platform) {
  var theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  theme = theme.copyWith(platform: platform);
  if (Platform.environment['SETTINGS_UI_FONT'] == null) return theme;
  ButtonStyle font(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          (style?.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
            fontFamily: 'SettingsUi',
          ),
        ),
      );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'SettingsUi'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'SettingsUi'),
    filledButtonTheme: FilledButtonThemeData(
      style: font(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: font(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(theme.textButtonTheme.style),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
        fontFamily: 'SettingsUi',
      ),
      subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(
        fontFamily: 'SettingsUi',
      ),
    ),
  );
}

Widget _app({required TargetPlatform platform, double textScale = 1}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore.memory()),
      authControllerProvider.overrideWith((ref) => _Auth()),
      assistControllerProvider.overrideWith(
        (ref) => AssistController(
          ref,
          initial: const AssistUiState(ready: true),
          bootstrap: false,
        ),
      ),
      appUpdateControllerProvider.overrideWith(
        (ref) => AppUpdateController(
          service: FakeUpdateService(),
          package: PackageInfo.fromPlatform,
          target: platform == TargetPlatform.android
              ? UpdateTarget.android
              : UpdateTarget.windows,
        ),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light, platform),
        darkTheme: _theme(Brightness.dark, platform),
        themeMode: switch (ref.watch(themePreferenceProvider)) {
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
          ThemePreference.system => ThemeMode.system,
        },
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: _SettingsFrame(platform: platform),
      ),
    ),
  );
}

// Render the production page and shell widgets, without bootstrapping live
// accounts, platform window services or the other tabs' background work.
class _SettingsFrame extends StatelessWidget {
  const _SettingsFrame({required this.platform});
  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (platform == TargetPlatform.android) {
      return Scaffold(
        body: const SettingsPage(),
        bottomNavigationBar: AppMobileNav(
          current: AppDestination.settings,
          onSelect: (_) {},
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(title: '厦大签到'),
          Container(height: 1, color: p.border),
          Expanded(
            child: Row(
              children: [
                AppSidebar(current: AppDestination.settings, onSelect: (_) {}),
                Container(width: 1, color: p.border),
                const Expanded(child: SettingsPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '厦大签到',
      packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
      version: '0.1.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  setUpAll(() async {
    final font = Platform.environment['SETTINGS_UI_FONT'];
    if (font == null) return;
    await (FontLoader(
      'SettingsUi',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            Platform.environment['SETTINGS_UI_ICONS']!,
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    expect(tester.takeException(), isNull);
    if (Platform.environment['CAPTURE_SETTINGS_UI'] != '1') return;
    await tester.runAsync(() async {
      final dir = await Directory(
        '.tools/settings-polish',
      ).create(recursive: true);
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 384.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets('settings remain usable at $width, dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'theme_preference':
              (dark ? ThemePreference.dark : ThemePreference.light).index,
        });
        final desktop = width >= 600;
        tester.view.physicalSize = Size(width, desktop ? 720 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: _app(
              platform: desktop
                  ? TargetPlatform.windows
                  : TargetPlatform.android,
              textScale: width == 320 ? 1.3 : 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('常用'), findsOneWidget);
        expect(find.text('应用'), findsOneWidget);
        for (final removed in ['账号', '检测', '更多', '窗口']) {
          expect(find.text(removed), findsNothing);
        }
        expect(find.text(desktop ? '桌面提醒' : '后台提醒'), findsOneWidget);
        expect(find.text('关闭窗口时'), desktop ? findsOneWidget : findsNothing);
        final segment = find.byType(AppSegmentedControl<ThemePreference>);
        if (desktop) {
          expect(segment, findsNothing);
          final appearance = find.byType(AppShellSelect<ThemePreference>);
          final close = find.byType(AppShellSelect<CloseMode>);
          expect(tester.getRect(appearance).right, tester.getRect(close).right);
          expect(tester.getSize(appearance).width, tester.getSize(close).width);
          final appGroup = find.ancestor(
            of: appearance,
            matching: find.byType(SettingsSection),
          );
          expect(tester.widget<SettingsSection>(appGroup).header, '应用');
        } else {
          final options = ['浅色', '暗色', '系统'].map(find.text).toList();
          expect(
            tester.getCenter(options.first).dy,
            tester.getCenter(options.last).dy,
          );
          expect(tester.getSize(segment).height, lessThan(60));
          final target = find
              .ancestor(of: options[1], matching: find.byType(InkWell))
              .first;
          expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
        }
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}',
        );

        await tester.scrollUntilVisible(find.text('关于'), 180);
        final route = find.byKey(const ValueKey('update-route-select'));
        expect(
          tester.getCenter(route).dx,
          greaterThan(tester.getCenter(find.text('更新下载线路')).dx),
        );
        await tester.tap(route);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsWidgets);
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}-routes',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNothing);
        await tester.tap(find.text('关于'));
        await tester.pumpAndSettle();
        expect(find.text('检查更新'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        final login = find.widgetWithText(FilledButton, '登录');
        await tester.scrollUntilVisible(login, -180);
        await Scrollable.ensureVisible(tester.element(login), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(login);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}-login',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'desktop appearance uses a right-aligned menu and persists the choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme_preference': ThemePreference.light.index,
      });
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(platform: TargetPlatform.windows));
      await tester.pumpAndSettle();
      final menu = find.byType(AppShellSelect<ThemePreference>);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('跟随系统'), findsOneWidget);
      await tester.tap(find.text('暗色'));
      await tester.pumpAndSettle();
      final page = tester.element(find.byType(SettingsPage));
      expect(Theme.of(page).brightness, Brightness.dark);
      expect(find.byType(AppMenuOption), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_preference'), ThemePreference.dark.index);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'appearance supports keyboard, pointer, semantics and persistence',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme_preference': ThemePreference.light.index,
      });
      tester.view.physicalSize = const Size(384, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.tap(find.text('暗色'));
      await tester.pumpAndSettle();
      final page = tester.element(find.byType(SettingsPage));
      expect(Theme.of(page).brightness, Brightness.dark);
      Focus.of(tester.element(find.text('暗色'))).requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('暗色')),
        matchesSemantics(
          label: '暗色',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          isFocusable: true,
          isFocused: true,
          hasFocusAction: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(page).read(themePreferenceProvider),
        ThemePreference.system,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(Theme.of(page).brightness, Brightness.light);
      Focus.of(tester.element(find.text('暗色'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(Theme.of(page).brightness, Brightness.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_preference'), ThemePreference.dark.index);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      await tester.pumpWidget(_app(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('primary button text retains readable contrast in both themes', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final a = theme.colorScheme.primary.computeLuminance();
      final b = theme.colorScheme.onPrimary.computeLuminance();
      expect(
        (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
