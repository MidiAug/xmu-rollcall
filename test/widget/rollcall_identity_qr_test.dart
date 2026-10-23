import 'dart:ui' show PointerDeviceKind;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/platform/desktop_qr_scanner.dart';
import '../fixtures/desktop_ui_capture.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '主号'),
    );
  }
}

class _Service extends Fake implements AssistService {
  final sessions = <int>[];
  @override
  Future<void> ensureSession(AssistIdentity identity) async {
    sessions.add(identity.userId);
  }

  @override
  Future<AssistIdentity> ensureDeviceId(AssistIdentity identity) async =>
      identity;
}

const _roster = [
  AssistIdentity(
    userId: 2,
    displayName: '未签同学',
    kind: AssistCredentialKind.session,
    deviceId: 'device-2',
  ),
  AssistIdentity(
    userId: 3,
    displayName: '已签同学',
    kind: AssistCredentialKind.session,
    deviceId: 'device-3',
  ),
  AssistIdentity(
    userId: 4,
    displayName: '其他课程同学',
    kind: AssistCredentialKind.session,
    deviceId: 'device-4',
  ),
];
final _data = <String, List<Map<String, dynamic>>>{};
final _puts = <({String session, Map body})>[];
Map<String, dynamic> _row({
  int id = 9001,
  bool signed = false,
  String title = '高等数学',
}) => {
  'rollcall_id': id,
  'course_id': 501,
  'course_title': title,
  'type': 'qr_rollcall',
  'source': 'qr',
  'status': signed ? 'on_call_fine' : 'absent',
};

class _Client extends TronHttpClient {
  _Client({required super.store, required super.sessionKey});
  @override
  Future<void> init() async {}
  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: uri.path),
    statusCode: 200,
    data: {'rollcalls': _data[sessionKey.storageId] ?? []} as T,
  );
  @override
  Future<Response<T>> putUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _puts.add((session: sessionKey.storageId, body: data as Map));
    _data[sessionKey.storageId] = [_row(signed: true)];
    return Response<T>(
      requestOptions: RequestOptions(path: uri.path),
      statusCode: 200,
      data: {'ok': true} as T,
    );
  }
}

class _Lists extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? id) async =>
      (_data[id == null ? 'owner' : SessionKey.assist(id).storageId] ?? [])
          .map(RollcallItem.fromJson)
          .toList();
}

var _appearanceChecks = 0;
var _manualChecks = 0;

class _AppearanceLists extends _Lists {
  @override
  Future<void> ensureFreshOnAppear() async {
    _appearanceChecks++;
  }

  @override
  Future<void> refresh() async {
    _manualChecks++;
  }
}

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => [];
}

class _AccountHomework extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async {
    final id = ref.watch(selectedRollcallAccountProvider);
    return HomeworkOverview([
      HomeworkItem(
        id: 1,
        title: id == null ? '主号作业' : '协助作业',
        courseName: '测试课',
        type: 'exam',
      ),
    ]);
  }

  @override
  Future<void> ensureFresh({bool force = false}) async {}
}

class _RunningMonitor extends MonitorController {
  _RunningMonitor(super.ref) {
    state = state.copyWith(running: true, loadingSettings: false);
  }
  void finish() =>
      state = state.copyWith(running: false, loadingSettings: false);
}

void main() {
  setUpAll(loadDesktopUiCaptureFonts);
  tearDown(AppToast.dismiss);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _puts.clear();
    _data.clear();
    _data['owner'] = [_row(title: '本人课程')];
    _data[SessionKey.assist(2).storageId] = [_row(title: '协助课程')];
    _data[SessionKey.assist(3).storageId] = [_row(signed: true)];
    _data[SessionKey.assist(4).storageId] = [_row(id: 9002)];
  });

  Future<_Service> show(
    WidgetTester tester,
    Widget page, {
    bool visibleTab = false,
  }) async {
    final store = SecureStore.memory();
    final service = _Service();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          homeworkTodosProvider.overrideWith(_Todos.new),
          homeworkOverviewProvider.overrideWith(_AccountHomework.new),
          currentTeachingCoursesProvider.overrideWith((ref) async => []),
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistServiceProvider.overrideWith((ref) async => service),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(identities: _roster, ready: true),
              bootstrap: false,
            ),
          ),
          sessionClientRegistryProvider.overrideWith(
            (ref) => SessionClientRegistry(
              store: store,
              createClient:
                  ({
                    required store,
                    required sessionKey,
                    required rateLimiter,
                  }) => _Client(store: store, sessionKey: sessionKey),
            ),
          ),
          activeRollcallsProvider.overrideWith(
            visibleTab ? _AppearanceLists.new : _Lists.new,
          ),
          if (visibleTab)
            monitorControllerProvider.overrideWith(_RunningMonitor.new),
        ],
        child: RepaintBoundary(
          key: const ValueKey('desktop-ui-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: desktopCaptureTheme(AppTheme.light()),
            home: Scaffold(
              body: visibleTab
                  ? ShellTabScope(
                      current: AppDestination.rollcall,
                      retapEpoch: 0,
                      retapDestination: null,
                      child: page,
                    )
                  : page,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets(
    'desktop sidebar is the single account entry across both pages',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = await show(tester, const AdaptiveShell());
      final menu = find.byKey(const ValueKey('rollcall-identity-menu'));
      expect(menu, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppSidebar), matching: menu),
        findsOneWidget,
      );
      expect(find.text('主号'), findsOneWidget);
      await captureDesktopUi(tester, 'sidebar-rollcall');
      Navigator.of(tester.element(find.byType(RollcallHubPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('旧账号签到详情')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('未签同学').last);
      await tester.pumpAndSettle();
      expect(find.text('协助课程'), findsOneWidget);
      expect(find.text('旧账号签到详情'), findsNothing);
      expect(service.sessions, contains(2));
      await tester.tap(find.text('作业').first);
      await tester.pumpAndSettle();
      expect(find.text('未签同学'), findsOneWidget);
      expect(find.text('协助作业'), findsOneWidget);
      await captureDesktopUi(tester, 'sidebar-homework');
      Navigator.of(tester.element(find.byType(HomeworkHubPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('旧账号作业详情')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('主号').last);
      await tester.pumpAndSettle();
      expect(find.text('主号作业'), findsOneWidget);
      expect(find.text('旧账号作业详情'), findsNothing);
      expect(find.text('主号'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'running detection owns automatic refresh, manual refresh remains available',
    (tester) async {
      _appearanceChecks = 0;
      _manualChecks = 0;
      await show(tester, const RollcallHubPage(), visibleTab: true);
      final context = tester.element(find.byType(RollcallHubPage));
      final container = ProviderScope.containerOf(context);
      for (var i = 0; i < 3; i++) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 25));
      }
      expect(_appearanceChecks, 0);
      await tester.tap(find.byType(AppRefreshButton));
      await tester.pumpAndSettle();
      expect(_manualChecks, 1);
      (container.read(monitorControllerProvider.notifier) as _RunningMonitor)
          .finish();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_appearanceChecks, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'narrow sign-in toolbar switches list/session and QR opens secondary page',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = await show(tester, const RollcallHubPage());
      expect(find.text('本人课程'), findsOneWidget);
      expect(find.text('主号'), findsOneWidget);
      expect(find.text('主号（本人）'), findsNothing);
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(
        tester.getTopLeft(find.text('主号')).dy,
        lessThan(tester.getTopLeft(find.text('开始检测')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('rollcall-identity-menu')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AppMenuOption).first).width,
        lessThanOrEqualTo(220),
      );
      await tester.tap(find.text('未签同学').last);
      await tester.pumpAndSettle();
      expect(find.text('协助课程'), findsOneWidget);
      expect(find.text('本人课程'), findsNothing);
      expect(service.sessions, contains(2));
      await tester.tap(find.text('扫码签到'));
      await tester.pumpAndSettle();
      expect(find.byType(QrAnswerPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final dark in [false, true]) {
    testWidgets(
      'identity hover stays inset and supports keyboard ($dark)',
      (tester) async {
        tester.view.physicalSize = const Size(960, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(
          tester,
          Theme(
            data: dark ? AppTheme.dark() : AppTheme.light(),
            child: const RollcallHubPage(),
          ),
        );
        expect(find.byTooltip('切换签到用户'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('rollcall-identity-menu')));
        await tester.pumpAndSettle();
        final option = find.ancestor(
          of: find.text('未签同学'),
          matching: find.byType(AppMenuOption),
        );
        final entry = find
            .ancestor(
              of: option,
              matching: find.byWidgetPredicate(
                (w) => w is Material && w.shape is RoundedRectangleBorder,
              ),
            )
            .first;
        expect(
          tester.getRect(option).left,
          greaterThan(tester.getRect(entry).left),
        );
        expect(
          tester.getRect(option).right,
          lessThan(tester.getRect(entry).right),
        );
        // There is only the shared inset InkWell; no full-width parent hover wash.
        expect(
          find.descendant(of: entry, matching: find.byType(InkWell)),
          findsNWidgets(
            find
                .descendant(of: entry, matching: find.byType(AppMenuOption))
                .evaluate()
                .length,
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(option));
        await tester.pumpAndSettle();
        final context = tester.element(option);
        final paint = tester.widget<AnimatedContainer>(
          find.descendant(of: option, matching: find.byType(AnimatedContainer)),
        );
        expect(
          (paint.decoration! as BoxDecoration).color,
          AppPalette.of(context).hover,
        );
        expect(find.byTooltip('未签同学'), findsNothing);
        Focus.of(tester.element(find.text('未签同学'))).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNothing);
        expect(find.text('协助课程'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'QR page rechecks a selected person who signed before submission',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, QrAnswerPage(item: RollcallItem.fromJson(_row())));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('未签同学'));
      _data[SessionKey.assist(2).storageId] = [_row(signed: true)];
      await tester.enterText(find.byType(TextField), 'QR_TEST_DATA');
      await tester.tap(
        find.text(DesktopQrScanner.supported ? '粘贴内容并提交' : '确认并提交'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_puts.map((call) => call.session), ['owner']);
      expect(find.text('已签到，无需重复提交'), findsOneWidget);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'QR page checks same event and submits selected unsigned people with their device ids',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, QrAnswerPage(item: RollcallItem.fromJson(_row())));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('未签同学'), findsOneWidget);
      expect(find.text('已签同学'), findsOneWidget);
      expect(find.text('其他课程同学'), findsNothing);
      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.last.onChanged, isNull);
      await tester.tap(find.text('未签同学'));
      final encoded = Uri.https('c-mobile.xmu.edu.cn', '/j', {
        'p':
            '0~\x10${501.toRadixString(36)}!3~QR_TEST_DATA!4~\x10${9001.toRadixString(36)}',
      }).toString();
      await tester.enterText(find.byType(TextField), encoded);
      await tester.tap(
        find.text(DesktopQrScanner.supported ? '粘贴内容并提交' : '确认并提交'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_puts.map((call) => call.session), [
        'owner',
        SessionKey.assist(2).storageId,
      ]);
      expect(_puts.last.body['deviceId'], 'device-2');
      expect(
        _puts.every((call) => call.body['data'] == 'QR_TEST_DATA'),
        isTrue,
      );
      expect(find.text('完成：2/2 成功'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  for (final width in [320.0, 384.0, 900.0]) {
    testWidgets('account settings fit $width with automatic rules expanded', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, const MonitorSettingsPage());
      final context = tester.element(find.byType(MonitorSettingsPage));
      final container = ProviderScope.containerOf(context);
      container.read(selectedRollcallAccountProvider.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(find.text('自动检测 · 当前账号'), findsNothing);
      expect(find.byKey(const ValueKey('monitor-auto-answer')), findsOneWidget);
      expect(find.text('更多设置'), findsNothing);
      expect(find.text('随机扰动'), findsOneWidget);
      expect(find.text('±20%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('monitor-auto-answer')));
      await tester.pumpAndSettle();
      expect(find.text('等待比例'), findsOneWidget);
      await tester.tap(find.byType(AppShellSelect<AnswerWaitMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('等待人数'));
      await tester.pumpAndSettle();
      expect(find.text('10 人'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final interval = find.byKey(const ValueKey('monitor-interval'));
      await tester.ensureVisible(interval);
      await tester.pumpAndSettle();
      final track = tester.getRect(interval);
      await tester.tapAt(Offset(track.right - 8, track.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('300 秒'), findsOneWidget);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'selected imported account can include the directly logged-in peer in QR batch',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(
        tester,
        QrAnswerPage(item: RollcallItem.fromJson(_row()), assistUserId: 2),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('主号'), findsOneWidget);
      await tester.tap(find.text('主号'));
      await tester.enterText(find.byType(TextField), 'QR_TEST_DATA');
      await tester.tap(
        find.text(DesktopQrScanner.supported ? '粘贴内容并提交' : '确认并提交'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_puts.map((c) => c.session), [
        SessionKey.assist(2).storageId,
        'owner',
      ]);
      expect(_puts.first.body['deviceId'], 'device-2');
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
