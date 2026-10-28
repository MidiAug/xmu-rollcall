import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/desktop_back_navigation.dart';
import '../fixtures/desktop_back_input.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import '../fixtures/update_fakes.dart';

class _TestAuthController extends AuthController {
  _TestAuthController()
    : super(
        AuthRepository(
          http: TronHttpClient(store: SecureStore()),
          store: SecureStore(),
        ),
      );

  @override
  Future<void> bootstrap() async {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

class _EmptyRollcalls extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? assistUserId) async => const [];
}

class _EmptyCourseHistory extends CourseHistoryNotifier {
  @override
  Future<List<CourseRollcallRecord>> build() async => const [];
}

void main() {
  testWidgets('Android bottom navigation is only visible on tab home pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppMobileNav), matching: find.text('我的')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('数据与诊断'));
    await tester.tap(find.text('数据与诊断'));
    await tester.pumpAndSettle();
    expect(find.byType(AppMobileNav), findsNothing);
    expect(find.byKey(const ValueKey('global-search-button')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppMobileNav), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('global-search-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AppMobileNav), findsNothing);
    expect(find.byKey(const ValueKey('campus-search-field')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppMobileNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hot reload clears retained place warning after matching rules change',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var room = '文宣楼B404、C405';
      final scope = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
          coursePlaceGroupsProvider.overrideWith((ref) {
            ref.watch(campusCachedDataProvider);
            return [
              CoursePlaceGroup(room, [room], ['课程示例']),
            ];
          }),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AdaptiveShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hint = find.byTooltip('有上课地点未定位，请在地图上标记');
      expect(scope.read(unmatchedRoomsProvider), isNotEmpty);
      expect(hint, findsOneWidget);
      // Simulate retained pre-reload provider output; the data now resolves to B.
      room = '文宣楼(4号楼）B404、B405';
      await tester.pump();
      expect(scope.read(unmatchedRoomsProvider), isNotEmpty);
      final reassembled = tester.binding.reassembleApplication();
      await tester.pumpAndSettle();
      await reassembled;
      await tester.pumpAndSettle();
      expect(scope.read(unmatchedRoomsProvider), isEmpty);
      expect(hint, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 960.0]) {
    testWidgets('My tab update hint follows shared state at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeUpdateService();
      final pending = StateProvider<bool>((ref) => false);
      final controller = AppUpdateController(
        service: service,
        package: () async => PackageInfo(
          appName: 'test',
          packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
          version: '0.1.1',
          buildNumber: '2',
        ),
        target: width < 600 ? UpdateTarget.android : UpdateTarget.windows,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
            appUpdateControllerProvider.overrideWith((ref) => controller),
            hasIncompleteCourseScheduleProvider.overrideWith(
              (ref) => ref.watch(pending),
            ),
          ],
          child: MaterialApp(
            theme: width < 600 ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width < 600 ? 1.3 : 1)),
              child: child!,
            ),
            home: const AdaptiveShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.byType(width < 600 ? AppMobileNav : AppSidebar);
      final myTab = find.descendant(
        of: nav,
        matching: find.text(width < 600 ? '我的' : '设置'),
      );
      final badges = width < 600
          ? find.descendant(of: nav, matching: find.byType(Badge))
          : find.byKey(const ValueKey('desktop-notice-settings'));
      final initialNavSize = tester.getSize(nav);
      final initialTabRect = tester.getRect(myTab);
      expect(badges, findsNothing);
      expect(service.checks, 0); // Rendering a hint never starts a check.

      service.checkError = const UpdateException('offline');
      await controller.check(force: true);
      await tester.pumpAndSettle();
      expect(badges, findsNothing);

      service.checkError = null;
      service.pendingCheck = Completer<ReleaseUpdate?>();
      final check = controller.check(force: true);
      await tester.pump();
      expect(badges, findsNothing); // Checking alone is not an update.
      service.pendingCheck!.complete(
        ReleaseUpdate(
          version: const AppVersion(0, 2, 0, 3),
          target: controller.target!,
          notes: 'fixture',
          size: 100,
          sha256: '0' * 64,
        ),
      );
      await check;
      service.pendingCheck = null;
      await tester.pumpAndSettle();
      expect(badges, findsOneWidget);
      if (width < 600) {
        expect(
          find.descendant(of: badges, matching: find.byIcon(AppIcons.person)),
          findsOneWidget,
        );
      } else {
        expect(
          tester.getRect(badges).left,
          greaterThan(tester.getRect(myTab).right),
        );
      }
      expect(find.byTooltip('有新版本可更新'), findsOneWidget);
      expect(tester.getSize(nav), initialNavSize);
      expect(tester.getRect(myTab), initialTabRect);

      await tester.tap(myTab);
      await tester.pumpAndSettle();
      expect(badges, findsOneWidget); // Selecting My does not dismiss it.
      expect(
        width < 600
            ? tester.widget<AppMobileNav>(nav).current
            : tester.widget<AppSidebar>(nav).current,
        AppDestination.settings,
      );
      await tester.tap(find.descendant(of: nav, matching: find.text('签到')));
      await tester.pumpAndSettle();
      expect(badges, findsOneWidget);
      expect(service.checks, 2); // Switching tabs does not check again.

      service.checkError = const UpdateException('offline');
      await controller.check(force: true);
      await tester.pumpAndSettle();
      expect(badges, findsOneWidget); // Keep a previously confirmed update.

      service.checkError = null;
      service.result = null;
      await controller.check(force: true);
      await tester.pumpAndSettle();
      expect(badges, findsNothing);
      expect(find.byTooltip('有新版本可更新'), findsNothing);
      expect(tester.getRect(myTab), initialTabRect);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdaptiveShell)),
      );
      container.read(pending.notifier).state = true;
      await tester.pumpAndSettle();
      expect(badges, findsNothing);
      expect(find.byTooltip('课表待完善'), findsNothing);
      expect(tester.getRect(myTab), initialTabRect);
      container.read(pending.notifier).state = false;
      await tester.pumpAndSettle();
      expect(badges, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('AdaptiveShell shows mobile nav on narrow width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const AdaptiveShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppMobileNav), findsOneWidget);
    expect(find.text('签到'), findsWidgets);
    expect(find.text('作业'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    final nav = find.byType(AppMobileNav);
    expect(find.descendant(of: nav, matching: find.text('工具')), findsOneWidget);
    expect(find.byType(CampusToolsPage), findsNothing);
    await tester.tap(find.descendant(of: nav, matching: find.text('工具')));
    await tester.pumpAndSettle();
    expect(find.byType(CampusToolsPage), findsOneWidget);
    expect(find.text('GPA 计算器'), findsOneWidget);
    expect(
      tester.widget<AppMobileNav>(nav).current,
      AppDestination.campusTools,
    );
    expect(find.text('校园工具'), findsNothing);
    await tester.tap(find.descendant(of: nav, matching: find.text('签到')));
    await tester.pumpAndSettle();
    expect(find.byType(CampusToolsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdaptiveShell shows sidebar on wide width', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const AdaptiveShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.text('签到'), findsWidgets);
    expect(find.text('作业'), findsWidgets);
    expect(find.text(PlatformHooks.isDesktop ? '设置' : '我的'), findsWidgets);
    expect(find.text('XMU TronClass'), findsNothing);
  });

  testWidgets(
    'desktop nested subpage owns its header while window identity remains stable',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final desktopNavigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
            courseHistoryProvider.overrideWith(_EmptyCourseHistory.new),
          ],
          child: MaterialApp(
            navigatorKey: desktopNavigator,
            builder: (context, child) => DesktopBackNavigation(
              navigatorKey: desktopNavigator,
              child: child!,
            ),
            theme: AppTheme.dark().copyWith(platform: TargetPlatform.windows),
            home: const AdaptiveShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('厦大签到'), findsOneWidget);

      await tester.tap(find.byTooltip('签到记录'));
      await tester.pumpAndSettle();

      expect(find.text('签到记录'), findsWidgets);
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(find.text('厦大签到'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppTitleBar),
          matching: find.byTooltip('返回'),
        ),
        findsNothing,
      );

      final oldBack = tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('返回'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed!;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byTooltip('返回'), findsNothing);
      expect(find.text('厦大签到'), findsOneWidget);
      oldBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('签到记录'));
      await tester.pumpAndSettle();
      await mouseBack(tester);
      expect(find.byTooltip('返回'), findsNothing);
      expect(find.text('厦大签到'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !PlatformHooks.isDesktop,
  );
}
