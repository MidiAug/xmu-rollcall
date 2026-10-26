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
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/features/settings/course_schedule_editor.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';

import '../fixtures/update_fakes.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth({bool signedIn = false}) : super(_Repository()) {
    state = signedIn
        ? const AuthState(
            status: AuthStatus.signedIn,
            profile: UserProfile(id: 1, name: '测试同学'),
          )
        : const AuthState(status: AuthStatus.signedOut);
  }
}

class _ScheduleCatalog extends CourseCatalogNotifier {
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: DateTime(2026, 10, 27),
    rolesResolved: true,
    courses: const [CatalogCourse(id: 'c', title: '待完善课程')],
  );
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

Widget _app({
  required TargetPlatform platform,
  double textScale = 1,
  bool needsSchedule = false,
}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore.memory()),
      authControllerProvider.overrideWith(
        (ref) => _Auth(signedIn: needsSchedule),
      ),
      if (needsSchedule)
        courseCatalogProvider.overrideWith(_ScheduleCatalog.new),
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

  for (final width in [320.0, 960.0]) {
    testWidgets('missing schedule chip precedes course arrow at $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'theme_preference': ThemePreference.light.index,
      });
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _app(
            platform: width > 600
                ? TargetPlatform.windows
                : TargetPlatform.android,
            textScale: width < 600 ? 1.3 : 1,
            needsSchedule: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('本学期课表'),
        matching: find.byType(SettingsRow),
      );
      final chip = find.descendant(of: row, matching: find.text('待完善'));
      final arrow = find.descendant(
        of: row,
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(chip, findsOneWidget);
      expect(
        tester.getBottomRight(chip).dx,
        lessThan(tester.getTopLeft(arrow).dx),
      );
      expect(
        find.descendant(of: row, matching: find.byType(Badge)),
        findsNothing,
      );
      await capture(tester, key, 'schedule-chip-${width.toInt()}');
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(CourseSchedulesPage), findsOneWidget);
      expect(find.byType(CoursesPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
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
        addTearDown(tester.view.resetViewInsets);
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
        expect(find.byType(AppSegmentedControl<ThemePreference>), findsNothing);
        final appearance = find.byType(AppShellSelect<ThemePreference>);
        final group = find.ancestor(
          of: appearance,
          matching: find.byType(SettingsSection),
        );
        expect(tester.widget<SettingsSection>(group).header, '应用');
        expect(
          tester.getCenter(appearance).dx,
          greaterThan(tester.getCenter(find.text('外观')).dx),
        );
        if (desktop) {
          final close = find.byType(AppShellSelect<CloseMode>);
          expect(tester.getRect(appearance).right, tester.getRect(close).right);
          expect(tester.getSize(appearance).width, tester.getSize(close).width);
        }
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}',
        );

        expect(find.byKey(const ValueKey('update-route-select')), findsNothing);
        await tester.scrollUntilVisible(find.text('关于'), 180);
        await tester.tap(find.text('关于'));
        await tester.pumpAndSettle();
        expect(find.text('检查更新'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('下载线路'), 100);
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}-about',
        );
        final route = find.byKey(const ValueKey('update-route-select'));
        expect(
          tester.getCenter(route).dx,
          greaterThan(tester.getCenter(find.text('下载线路')).dx),
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
        await tester.tap(route);
        await tester.pumpAndSettle();
        expect(find.text('自定义线路…'), findsNothing);
        expect(find.byType(AppMenuOption), findsNWidgets(3));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
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
    'signed out course entry opens login rather than ignoring the tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本学期课表'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'appearance menu supports pointer, keyboard and persistence on $platform',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'theme_preference': ThemePreference.light.index,
        });
        tester.view.physicalSize = Size(
          platform == TargetPlatform.windows ? 960 : 384,
          844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(platform: platform));
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
        final trigger = find.descendant(
          of: menu,
          matching: find.byType(AppSelectTrigger),
        );
        tester.widget<AppSelectTrigger>(trigger).focusNode!.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          ProviderScope.containerOf(page).read(themePreferenceProvider),
          ThemePreference.system,
        );
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('暗色'));
        await tester.pumpAndSettle();
        expect(
          (await SharedPreferences.getInstance()).getInt('theme_preference'),
          ThemePreference.dark.index,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_app(platform: platform));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(SettingsPage))).brightness,
          Brightness.dark,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [320.0, 960.0]) {
    testWidgets('device identity copies full stable value at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      const id = '00000000-1111-4222-8333-444444444444';
      final store = SecureStore.memory({SecureStore.keyDeviceId: id});
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: _theme(
              width < 600 ? Brightness.light : Brightness.dark,
              width < 600 ? TargetPlatform.android : TargetPlatform.windows,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width < 600 ? 1.3 : 1)),
              child: child!,
            ),
            home: RepaintBoundary(key: key, child: const SettingsDataPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('复制本机标识'));
      await capture(tester, key, '${width.toInt()}-device-id');
      await tester.tap(find.byTooltip('复制本机标识'));
      await tester.pumpAndSettle();
      expect(copied, id);
      expect(await store.read(SecureStore.keyDeviceId), id);
      expect(find.text('已复制本机标识'), findsOneWidget);
      expect(find.text('用于识别本机，重装应用前一般保持不变'), findsNothing);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
