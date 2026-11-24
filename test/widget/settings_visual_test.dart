import '../fixtures/desktop_ui_capture.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';

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
            profile: UserProfile(
              id: 1,
              name: '测试同学',
              raw: {'user_no': '2099000000001'},
            ),
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
  String college = '信息学院',
}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore.memory()),
      academicCachedScheduleProvider(1).overrideWith(
        (ref) async => AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 14),
          fetchedAt: DateTime(2026, 10, 29),
          rows: [],
          studentCollege: college,
        ),
      ),
      academicCachedScheduleProvider(2).overrideWith(
        (ref) async => AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 14),
          fetchedAt: DateTime(2026, 10, 29),
          rows: [],
          studentCollege: '其他账号学院',
        ),
      ),
      academicTimetableProvider(1).overrideWith(
        (ref) async => const AcademicTimetableState(
          message: '请重新登录账号以连接教务课表',
          needsLogin: true,
        ),
      ),
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
          child: AppDensityScope(child: child!),
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
          onSearch: () {},
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(title: '厦大签到'),
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
  initializeDesktopUiCapture();
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
    if (Platform.environment['CAPTURE_SETTINGS_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
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

  for (final dark in [false, true]) {
    testWidgets('settings scroll at window edge, dark=$dark', (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme_preference':
            (dark ? ThemePreference.dark : ThemePreference.light).index,
      });
      tester.view.physicalSize = const Size(1440, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _app(platform: TargetPlatform.windows),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(ListView),
      );
      final viewport = tester.getRect(list);
      expect(viewport.right, 1440);
      final group = find.byType(SettingsSection).first;
      final content = tester.getRect(group);
      expect(
        content.width,
        closeTo(AppLayout.contentMaxWidth - 2 * AppSpace.pageX, .1),
      );
      expect(content.center.dx, closeTo(viewport.center.dx, .1));
      final scrollbar = find.descendant(
        of: list,
        matching: find.byType(Scrollbar),
      );
      expect(scrollbar, findsOneWidget);
      expect(tester.getRect(scrollbar).right, 1440);
      final controller = tester.widget<ListView>(list).controller!;
      expect(controller.position.maxScrollExtent, greaterThan(0));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewport.center);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewport.center,
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 200));
      controller.jumpTo(0);
      await tester.pump();
      // Hit the painted native thumb at the page edge, then drag it.
      final thumb = Offset(viewport.right - 4, viewport.top + 12);
      await mouse.moveTo(thumb);
      await tester.pump(const Duration(milliseconds: 200));
      final paint =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: scrollbar,
                      matching: find.byWidgetPredicate(
                        (w) =>
                            w is CustomPaint &&
                            w.foregroundPainter is ScrollbarPainter,
                      ),
                    ),
                  )
                  .foregroundPainter!
              as ScrollbarPainter;
      expect(paint.fadeoutOpacityAnimation.value, greaterThan(0));
      expect(
        paint.hitTestOnlyThumbInteractive(
          thumb - viewport.topLeft,
          PointerDeviceKind.mouse,
        ),
        isTrue,
      );
      await capture(
        tester,
        key,
        'edge-scrollbar-before-${dark ? 'dark' : 'light'}',
      );
      await mouse.down(thumb);
      await tester.pump();
      await mouse.moveBy(const Offset(0, 24));
      await tester.pump();
      await mouse.moveBy(const Offset(0, 100));
      await tester.pump();
      await mouse.up();
      expect(controller.offset, greaterThan(50));
      await capture(tester, key, 'edge-scrollbar-${dark ? 'dark' : 'light'}');
      final offset = controller.offset;
      tester.view.physicalSize = const Size(960, 520);
      await tester.pumpAndSettle();
      expect(tester.getRect(list).right, 960);
      expect(controller.offset, closeTo(offset, .1));
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
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
        matching: find.byIcon(AppIcons.right),
      );
      expect(chip, findsNothing);
      await capture(tester, key, 'schedule-direct-${width.toInt()}');
      if (width > 600) {
        expect(find.text('本学期课表'), findsNothing);
        return;
      }
      await tester.tap(find.text('本学期课表'));
      await tester.pumpAndSettle();
      expect(find.byType(CoursesPage), findsOneWidget);
      expect(find.byType(CourseSchedulesPage), findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();
      expect(find.byType(CoursesPage), findsOneWidget);
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

        expect(find.text('常用'), findsNothing);
        expect(find.text('外观与窗口'), findsNothing);
        expect(find.text('应用'), findsNothing);
        expect(find.text('本学期课表'), desktop ? findsNothing : findsOneWidget);
        for (final removed in ['账号', '检测', '更多', '窗口']) {
          expect(find.text(removed), findsNothing);
        }
        expect(find.text('关闭窗口时'), desktop ? findsOneWidget : findsNothing);
        final appearance = desktop
            ? find.byType(AppSegmentedControl<ThemePreference>)
            : find.byType(AppShellSelect<ThemePreference>);
        if (desktop) {
          final group = find.ancestor(
            of: appearance,
            matching: find.byType(SettingsSection),
          );
          expect(tester.widget<SettingsSection>(group).header, isNull);
        } else {
          expect(find.byType(SettingsSection), findsWidgets);
        }
        expect(
          tester.getCenter(appearance).dx,
          greaterThan(tester.getCenter(find.text('外观')).dx),
        );
        if (desktop) {
          final close = find.byType(AppShellSelect<CloseMode>);
          expect(tester.getRect(appearance).right, tester.getRect(close).right);
          expect(find.text('浅色'), findsOneWidget);
          expect(find.text('暗色'), findsOneWidget);
          expect(find.text('跟随系统'), findsOneWidget);
        }
        await capture(
          tester,
          key,
          '${width.toInt()}-${dark ? 'dark' : 'light'}',
        );

        if (!desktop) {
          await tester.tap(appearance);
          await tester.pumpAndSettle();
          await capture(tester, key, 'appearance-r22-${width.toInt()}-$dark');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }

        if (desktop) {
          await tester.scrollUntilVisible(find.text('启动后继续值守'), 180);
          await tester.pumpAndSettle();
          expect(find.text('运行与启动'), findsNothing);
          expect(find.text('开机启动'), findsOneWidget);
          await capture(
            tester,
            key,
            '${width.toInt()}-${dark ? 'dark' : 'light'}-startup',
          );
        } else {
          expect(find.text('运行与启动'), findsNothing);
          expect(find.text('开机启动'), findsNothing);
        }
        await tester.scrollUntilVisible(
          find.text(desktop ? '桌面提醒' : '后台提醒'),
          180,
        );
        expect(find.text('通知与维护'), findsNothing);

        expect(find.byKey(const ValueKey('update-route-select')), findsNothing);
        await tester.scrollUntilVisible(find.text('关于'), 180);
        await Scrollable.ensureVisible(
          tester.element(find.text('关于')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
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
        final login = desktop
            ? find.widgetWithText(TextButton, '登录')
            : find.byKey(const ValueKey('android-profile-summary'));
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

  for (final dark in [false, true]) {
    testWidgets('mobile signed-in account management dark=$dark', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'theme_preference':
            (dark ? ThemePreference.dark : ThemePreference.light).index,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _app(platform: TargetPlatform.android, needsSchedule: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('我的'),
        findsNWidgets(2),
        reason:
            'The page title and bottom navigation both name this destination',
      );
      expect(find.text('信息学院'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(tester.widget<Text>(find.text('测试同学')).style?.fontSize, 16);
      expect(find.text('退出'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      container.read(selectedRollcallAccountProvider.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(find.text('信息学院'), findsOneWidget);
      expect(find.text('其他账号学院'), findsNothing);
      await capture(tester, key, 'mobile-account-${dark ? 'dark' : 'light'}');
      await tester.tap(find.byKey(const ValueKey('android-profile-summary')));
      await tester.pumpAndSettle();
      expect(find.text('退出登录'), findsOneWidget);
      expect(find.text('测试同学'), findsNWidgets(2));
      await capture(tester, key, 'account-management-r22-$dark');
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('退出登录'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('R25 touch settings share row geometry at $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(platform: platform, needsSchedule: true));
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('地点管理'),
        matching: find.byType(SettingsRow),
      );
      expect(tester.getSize(row).height, 60);
      expect(
        find.byKey(const ValueKey('profile-college')),
        platform == TargetPlatform.android ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('narrow profile keeps long college and account action usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          platform: TargetPlatform.android,
          needsSchedule: true,
          textScale: 1.3,
          college: '电子科学与技术学院（国家示范性微电子学院）',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-college')), findsOneWidget);
    await capture(tester, key, 'mobile-account-narrow');
    await tester.tap(find.byKey(const ValueKey('android-profile-summary')));
    await tester.pumpAndSettle();
    expect(find.text('退出登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

  for (final dark in [false, true]) {
    testWidgets(
      'production appearance segments show complete keyboard rings dark=$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'theme_preference':
              (dark ? ThemePreference.dark : ThemePreference.light).index,
        });
        tester.view.physicalSize = const Size(960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: _app(platform: TargetPlatform.windows),
          ),
        );
        await tester.pumpAndSettle();
        final initialRender =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final baseline = (await tester.runAsync(() async {
          final image = await initialRender.toImage();
          try {
            return (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        }))!;
        for (final preference in ThemePreference.values) {
          final segment = find.byKey(ValueKey(preference));
          final node = tester
              .widget<FocusableActionDetector>(
                find.descendant(
                  of: segment,
                  matching: find.byType(FocusableActionDetector),
                ),
              )
              .focusNode!;
          for (var i = 0; i < 30 && !node.hasFocus; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
          }
          expect(node.hasFocus, isTrue);
          final rect = tester.getRect(segment);
          final render =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final offset = render.globalToLocal(rect.topLeft);
          await tester.runAsync(() async {
            final image = await render.toImage();
            try {
              final rgba = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              for (final point in [
                Offset(2, rect.height / 2),
                Offset(rect.width - 3, rect.height / 2),
                Offset(rect.width / 2, 2),
                Offset(rect.width / 2, rect.height - 3),
              ]) {
                final spot = offset + point;
                final index =
                    (spot.dy.floor() * image.width + spot.dx.floor()) * 4;
                expect(
                  Color.fromARGB(
                    rgba[index + 3],
                    rgba[index],
                    rgba[index + 1],
                    rgba[index + 2],
                  ),
                  isNot(
                    Color.fromARGB(
                      baseline[index + 3],
                      baseline[index],
                      baseline[index + 1],
                      baseline[index + 2],
                    ),
                  ),
                  reason: '$preference must paint a full edge at $point',
                );
              }
            } finally {
              image.dispose();
            }
          });
          await capture(
            tester,
            key,
            'appearance-focus-${preference.name}-$dark',
          );
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'appearance choices support pointer, keyboard and persistence on $platform',
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
        final desktop = platform == TargetPlatform.windows;
        final menu = find.byType(AppShellSelect<ThemePreference>);
        if (!desktop) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
        }
        expect(find.text('跟随系统'), findsOneWidget);
        await tester.tap(find.text('暗色'));
        await tester.pumpAndSettle();
        final page = tester.element(find.byType(SettingsPage));
        expect(Theme.of(page).brightness, Brightness.dark);
        expect(find.byType(AppMenuOption), findsNothing);
        if (desktop) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        } else {
          tester
              .widget<SettingsRow>(
                find
                    .descendant(of: menu, matching: find.byType(SettingsRow))
                    .first,
              )
              .focusNode!
              .requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
        }
        expect(
          ProviderScope.containerOf(page).read(themePreferenceProvider),
          ThemePreference.system,
        );
        if (!desktop) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
        }
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
  test('secondary text is readable on semantic desktop surfaces', () {
    for (final p in [AppPalette.lightPalette, AppPalette.darkPalette]) {
      for (final surface in [
        p.canvas,
        p.surface,
        p.content,
        p.sidebar,
        p.mobileCanvas,
        p.controlSurface,
        p.accentSurface,
        Color.alphaBlend(p.selected, p.surface),
      ]) {
        final a = p.muted.computeLuminance();
        final b = surface.computeLuminance();
        expect(
          (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}
