import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_identities_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import '../fixtures/preview_fonts.dart';

class _Empty extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? assistUserId) async => const [];
}

class _Routes extends NavigatorObserver {
  var pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Widget _app({
  required GlobalKey<NavigatorState> navigator,
  required bool dark,
  required VoidCallback onProbe,
  bool fail = false,
  bool Function()? shouldFail,
  Future<void> Function()? waitForProbe,
  NavigatorObserver? observer,
}) {
  final memory = SecureStore.memory();
  const identity = AssistIdentity(
    userId: 42,
    displayName: '同学甲',
    kind: AssistCredentialKind.session,
    deviceId: 'preview-device',
  );
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(memory),
      deviceIdentityProvider.overrideWith((ref) => DeviceIdentity(memory)),
      sessionClientRegistryProvider.overrideWith(
        (ref) => SessionClientRegistry(
          store: memory,
          createClient:
              ({required store, required sessionKey, required rateLimiter}) =>
                  TronHttpClient(
                    store: store,
                    sessionKey: sessionKey,
                    rateLimiter: rateLimiter,
                    cookieJar: CookieJar(),
                  ),
        ),
      ),
      assistServiceProvider.overrideWith(
        (ref) async => AssistService(
          store: memory,
          registry: ref.watch(sessionClientRegistryProvider),
          probeProfile: (_) async {
            onProbe();
            await waitForProbe?.call();
            if (shouldFail?.call() ?? fail) throw StateError('预览连接失败');
            return const AssistProfileSnapshot(id: 42, name: '同学甲');
          },
        ),
      ),
      assistControllerProvider.overrideWith(
        (ref) => AssistController(
          ref,
          initial: const AssistUiState(ready: true, identities: [identity]),
          bootstrap: false,
        ),
      ),
      activeRollcallsProvider.overrideWith(_Empty.new),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: observer == null ? const [] : [observer],
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (_, child) =>
          RepaintBoundary(key: const ValueKey('assist-capture'), child: child!),
      home: const AssistIdentitiesPage(),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['ASSIST_UI_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('assist-capture')),
        )
        .toImage();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

FocusNode _identityFocus(WidgetTester tester) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(const ValueKey('assist-open-42')),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

Future<void> _tabTo(WidgetTester tester, FocusNode target) async {
  // The production title bar has three keyboard targets before the roster.
  // Follow actual traversal rather than assume the first Tab opens identity.
  for (var i = 0; i < 12 && !target.hasFocus; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  expect(
    target.hasFocus,
    isTrue,
    reason: 'identity must be keyboard reachable',
  );
}

void main() {
  setUpAll(loadDesktopPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.dismiss);
  testWidgets(
    'pending identity preparation opens one route after repeated activation',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final routes = _Routes();
      final pending = Completer<void>();
      var probes = 0;
      await tester.pumpWidget(
        _app(
          navigator: navigator,
          dark: false,
          onProbe: () => probes++,
          waitForProbe: () => pending.future,
          observer: routes,
        ),
      );
      await tester.pumpAndSettle();
      final baseline = routes.pushes;
      final target = find.byKey(const ValueKey('assist-open-42'));
      await _tabTo(tester, _identityFocus(tester));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.text('同学甲'));
      await tester.pumpAndSettle();
      final busyVisible = find.text('正在连接…').evaluate().isNotEmpty;
      expect(probes, 1, reason: 'the real service coalesces its profile probe');
      expect(find.byType(RollcallHubPage), findsNothing);
      expect(tester.getRect(target).height, greaterThan(40));
      await _capture(tester, 'assist-pending');
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        routes.pushes,
        baseline + 1,
        reason: 'coalescing HTTP must also produce one navigation',
      );
      expect(busyVisible, isTrue);
      expect(find.byType(RollcallHubPage), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AssistIdentitiesPage), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets('capture assist roster baseline', (tester) async {
    await tester.pumpWidget(
      _app(navigator: GlobalKey<NavigatorState>(), dark: false, onProbe: () {}),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'assist-roster');
    expect(find.text('同学甲'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    for (final activation in ['pointer', 'enter', 'space']) {
      testWidgets(
        'identity opens through $activation and returns without a pointer focus border dark=$dark',
        (tester) async {
          final navigator = GlobalKey<NavigatorState>();
          var probes = 0;
          await tester.pumpWidget(
            _app(navigator: navigator, dark: dark, onProbe: () => probes++),
          );
          await tester.pumpAndSettle();
          final target = find.byKey(const ValueKey('assist-open-42'));
          final before = tester.getRect(target);
          final container = ProviderScope.containerOf(tester.element(target));
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          if (activation == 'pointer') {
            await mouse.moveTo(tester.getCenter(target));
            await tester.pumpAndSettle();
            expect(
              RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
              SystemMouseCursors.basic,
            );
            await _capture(tester, 'assist-hover-$dark');
            await mouse.down(tester.getCenter(target));
            await mouse.up();
          } else {
            await _tabTo(tester, _identityFocus(tester));
            await tester.sendKeyEvent(
              activation == 'enter'
                  ? LogicalKeyboardKey.enter
                  : LogicalKeyboardKey.space,
            );
          }
          await tester.pumpAndSettle();
          expect(probes, 1);
          expect(container.read(selectedRollcallAccountProvider), 42);
          expect(find.byType(RollcallHubPage), findsOneWidget);
          navigator.currentState!.pop();
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(find.byType(AssistIdentitiesPage), findsOneWidget);
          expect(tester.getRect(target), before);
          if (activation == 'pointer') {
            final body = tester.widget<AnimatedContainer>(
              find.descendant(
                of: target,
                matching: find.byType(AnimatedContainer),
              ),
            );
            expect((body.decoration! as BoxDecoration).border!.top.color.a, 0);
          }
          await _capture(tester, 'assist-return-$activation-$dark');
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
    testWidgets(
      'identity failure retains current account and permits retry dark=$dark',
      (tester) async {
        var probes = 0;
        await tester.pumpWidget(
          _app(
            navigator: GlobalKey<NavigatorState>(),
            dark: dark,
            shouldFail: () => probes == 1,
            onProbe: () => probes++,
          ),
        );
        await tester.pumpAndSettle();
        final target = find.byKey(const ValueKey('assist-open-42'));
        final container = ProviderScope.containerOf(tester.element(target));
        await _tabTo(tester, _identityFocus(tester));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(probes, 1);
        expect(container.read(selectedRollcallAccountProvider), isNull);
        expect(find.byType(RollcallHubPage), findsNothing);
        expect(find.byType(AssistIdentitiesPage), findsOneWidget);
        expect(find.textContaining('无法切换账号'), findsOneWidget);
        await _capture(tester, 'assist-failure-$dark');
        AppToast.dismiss();
        await tester.pumpAndSettle();
        await _tabTo(tester, _identityFocus(tester));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(probes, 2);
        expect(container.read(selectedRollcallAccountProvider), 42);
        expect(find.byType(RollcallHubPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('overflow is an independent target and never prepares identity', (
    tester,
  ) async {
    var probes = 0;
    await tester.pumpWidget(
      _app(
        navigator: GlobalKey<NavigatorState>(),
        dark: false,
        onProbe: () => probes++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('查看同课'), findsOneWidget);
    expect(probes, 0);
    expect(find.byType(RollcallHubPage), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _tabTo(tester, _identityFocus(tester));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byTooltip('更多'),
            matching: find.byType(Icon),
          ),
        ),
      ).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(probes, 0);
    expect(find.text('查看同课'), findsOneWidget);
    expect(find.byType(RollcallHubPage), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
