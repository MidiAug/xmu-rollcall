import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/rollcall/mobile_rollcall_home.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// Scoped preview with its own navigation so secondary pages retain the local
/// transport, including the repositories constructed inside the QR page.
class RollcallPreviewPage extends StatefulWidget {
  const RollcallPreviewPage({super.key});

  @override
  State<RollcallPreviewPage> createState() => _RollcallPreviewPageState();
}

class _RollcallPreviewPageState extends State<RollcallPreviewPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  // A fresh container prevents inherited account providers from resolving to
  // the live account's repository, history or locations outside this preview.
  late final _container = ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWith((ref) => SecureStore.memory()),
      sessionClientRegistryProvider.overrideWith(
        (ref) => SessionClientRegistry(
          store: ref.watch(secureStoreProvider),
          rateLimiter: RateLimiter(minInterval: Duration.zero),
          createClient:
              ({required store, required sessionKey, required rateLimiter}) =>
                  TronHttpClient(
                    store: store,
                    sessionKey: sessionKey,
                    rateLimiter: rateLimiter,
                    cookieJar: CookieJar(),
                    dio: Dio()
                      ..httpClientAdapter = _PreviewAdapter(
                        () =>
                            ref
                                .read(activeRollcallsProvider(null))
                                .valueOrNull ??
                            [],
                        (id) => ref
                            .read(activeRollcallsProvider(null).notifier)
                            .patchItem(
                              previewRollcalls
                                  .firstWhere((e) => e.rollcallId == id)
                                  .copyWith(status: 'on_call_fine'),
                            ),
                      ),
                  ),
        ),
      ),
      authControllerProvider.overrideWith(
        (ref) => _PreviewAuth(ref.read(authRepositoryProvider)),
      ),
      assistControllerProvider.overrideWith(
        (ref) => AssistController(
          ref,
          bootstrap: false,
          initial: const AssistUiState(ready: true),
        ),
      ),
      activeRollcallsProvider.overrideWith(_PreviewRollcalls.new),
      monitorControllerProvider.overrideWith(_PreviewMonitor.new),
      selectedDetectionWindowProvider.overrideWith(
        (ref) async => const DetectionWindow(enabled: false),
      ),
      campusNowProvider.overrideWithValue(() => _previewNow),
      campusClockProvider.overrideWith((ref) => Stream.value(_previewNow)),
      campusCachedDataProvider.overrideWith(
        (ref) async => CampusCachedData(
          schedule: AcademicSchedule(
            term: '20261',
            monday: DateTime(2026, 10, 26),
            fetchedAt: _previewNow,
            rows: [
              AcademicCourseRow.fromJson({
                'KCDM': 'preview-radar-9002',
                'BJDM': 'A',
                'KCMC': '工程伦理',
                'XQ': 5,
                'KSJCDM': 3,
                'JSJCDM': 4,
                'ZCBH': '1',
                'JASMC':
                    ref.watch(_scenarioProvider) ==
                        RollcallPreviewScenario.missing
                    ? '地点待补充'
                    : '学武楼（1号楼）A404',
                'startMinute': 610,
                'endMinute': 710,
              }),
              AcademicCourseRow.fromJson({
                'KCDM': 'preview-next',
                'BJDM': 'A',
                'KCMC': '软件测试',
                'XQ': 5,
                'KSJCDM': 7,
                'JSJCDM': 8,
                'ZCBH': '1',
                'JASMC': '西部片区2号楼108',
                'startMinute': 870,
                'endMinute': 970,
              }),
            ],
          ),
        ),
      ),
      currentCourseHistoryProvider.overrideWithValue(const AsyncData([])),
      historyProvider.overrideWith(
        (ref) => HistoryController(userId: 900001, migrateLegacy: false),
      ),
      savedLocationsProvider.overrideWith(
        (ref) => SavedLocationsController(
          storageKey: 'rollcall_developer_preview_locations',
        ),
      ),
      courseRadarDefaultsProvider.overrideWith(
        (ref) => CourseRadarDefaultsController(),
      ),
    ],
  );

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: _container,
    child: NavigatorPopHandler(
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => _RollcallPreviewContent(
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ),
  );
}

final _previewNow = DateTime(2026, 10, 30, 10, 20);

enum RollcallPreviewScenario {
  ready('三类待签 · 信息齐全'),
  missing('三类待签 · 缺码缺位置'),
  mixed('数字已签 · 定位与扫码待签'),
  completed('三类全部已签'),
  ended('数字待签 · 定位已签 · 扫码结束'),
  number('只有数字签到'),
  radar('只有定位签到'),
  qr('只有二维码签到'),
  empty('刷新后无签到'),
  loading('正在刷新'),
  detecting('检测中 · 三类待签'),
  failure('刷新失败');

  const RollcallPreviewScenario(this.label);
  final String label;
}

final _scenarioProvider = StateProvider((ref) => RollcallPreviewScenario.ready);

final previewRollcalls = [
  for (final type in [
    RollcallType.number,
    RollcallType.radar,
    RollcallType.qrcode,
  ])
    RollcallItem(
      rollcallId: 9001 + type.index,
      courseTitle: switch (type) {
        RollcallType.number => '专业英语',
        RollcallType.radar => '工程伦理',
        _ => '软件测试',
      },
      createdByName: '预览老师',
      type: type,
      status: '',
      rollcallStatus: '',
      isExpired: false,
      scored: false,
      numberCode: type == RollcallType.number ? '1234' : null,
      raw: type == RollcallType.radar
          ? {
              'course_id': 'preview-radar-9002',
              'created_at': _previewNow.toIso8601String(),
            }
          : const {},
    ),
];

List<RollcallItem> _scenarioItems(RollcallPreviewScenario scenario) {
  if (scenario == RollcallPreviewScenario.empty ||
      scenario == RollcallPreviewScenario.failure) {
    return [];
  }
  final singleType = switch (scenario) {
    RollcallPreviewScenario.number => RollcallType.number,
    RollcallPreviewScenario.radar => RollcallType.radar,
    RollcallPreviewScenario.qr => RollcallType.qrcode,
    _ => null,
  };
  return [
    for (final item in previewRollcalls)
      if (singleType == null || singleType == item.type)
        if (scenario == RollcallPreviewScenario.ended && item.isQrcode)
          RollcallItem(
            rollcallId: item.rollcallId,
            courseTitle: item.courseTitle,
            createdByName: item.createdByName,
            type: item.type,
            status: '',
            rollcallStatus: 'closed',
            isExpired: true,
            scored: false,
          )
        else
          item.copyWith(
            status:
                scenario == RollcallPreviewScenario.completed ||
                    (scenario == RollcallPreviewScenario.mixed &&
                        item.isNumber) ||
                    (scenario == RollcallPreviewScenario.ended && item.isRadar)
                ? 'on_call_fine'
                : '',
            clearNumberCode: scenario == RollcallPreviewScenario.missing,
            numberCodeError:
                scenario == RollcallPreviewScenario.missing && item.isNumber
                ? '未取得签到码'
                : null,
          ),
  ];
}

class _PreviewMonitor extends MonitorController {
  _PreviewMonitor(this.previewRef) : super(previewRef, bootstrap: false) {
    state = state.copyWith(loadingSettings: false);
  }
  final Ref previewRef;

  void showRunning(bool value) => state = state.copyWith(
    running: value,
    clearNext: !value,
    nextPollAt: value ? DateTime.now().add(const Duration(seconds: 30)) : null,
  );

  @override
  Future<StartMonitorResult> startAsync() async {
    state = state.copyWith(
      running: true,
      nextPollAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    await previewRef.read(activeRollcallsProvider(null).notifier).refresh();
    // Local simulation skips the real notification/permission setup flow.
    return StartMonitorResult.alreadyRunning;
  }

  @override
  void stop({String reason = 'user_stop'}) =>
      state = state.copyWith(running: false, clearNext: true);

  @override
  void pollNow({bool manual = true}) {
    previewRef.read(activeRollcallsProvider(null).notifier).refresh();
  }
}

class _PreviewAuth extends AuthController {
  _PreviewAuth(super.repo) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 900001, name: '预览同学'),
    );
  }
}

class _PreviewRollcalls extends ActiveRollcallsNotifier {
  bool _disposed = false;
  @override
  Future<List<RollcallItem>> build(int? assistUserId) async {
    ref.onDispose(() => _disposed = true);
    return [];
  }

  @override
  Future<void> refresh({bool manual = true}) async {
    final scenario = ref.read(_scenarioProvider);
    final hasInputs = scenario != RollcallPreviewScenario.missing;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    if (hasInputs) {
      final place = teachingPlaces.firstWhere(
        (p) => p.id == 'xmu:teaching:xuewu-a',
      );
      await prefs.setString(
        'course_radar_defaults_900001',
        jsonEncode({
          'id:preview-radar-9002': CourseRadarPref(
            courseTitle: '工程伦理',
            courseId: 'preview-radar-9002',
            latitude: place.latitude,
            longitude: place.longitude,
            labelSnapshot: place.name,
            obtainedVia: 'map',
            userConfigured: true,
          ).toJson(),
        }),
      );
    } else {
      await prefs.remove('course_radar_defaults_900001');
    }
    if (_disposed) return;
    lastUpdatedAt = DateTime.now();
    if (scenario == RollcallPreviewScenario.loading) {
      state = const AsyncLoading();
      return;
    }
    if (scenario == RollcallPreviewScenario.detecting) {
      (ref.read(monitorControllerProvider.notifier) as _PreviewMonitor)
          .showRunning(true);
    }
    if (scenario == RollcallPreviewScenario.failure) {
      state = AsyncError(StateError('模拟刷新失败'), StackTrace.current);
      return;
    }
    final previous = state.valueOrNull ?? [];
    state = AsyncData(previous.isEmpty ? _scenarioItems(scenario) : previous);
  }

  void selectScenario(RollcallPreviewScenario scenario) {
    ref.read(_scenarioProvider.notifier).state = scenario;
    (ref.read(monitorControllerProvider.notifier) as _PreviewMonitor)
        .showRunning(false);
    state = const AsyncData([]);
    lastUpdatedAt = null;
  }

  @override
  Future<void> ensureFreshOnAppear() async {}

  @override
  void patchItem(RollcallItem updated) {
    state = AsyncData([
      for (final item in state.valueOrNull ?? <RollcallItem>[])
        item.rollcallId == updated.rollcallId
            ? updated.copyWith(
                status: item.isAnswered ? item.status : updated.status,
              )
            : item,
    ]);
  }
}

class _RollcallPreviewContent extends ConsumerStatefulWidget {
  const _RollcallPreviewContent({required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<_RollcallPreviewContent> createState() =>
      _RollcallPreviewContentState();
}

class _RollcallPreviewContentState
    extends ConsumerState<_RollcallPreviewContent> {
  final _scroll = ScrollController();
  int _retapEpoch = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _otherPage() => AppToast.show(context, '此预览只展示签到首页与签到流程');

  @override
  Widget build(BuildContext context) {
    final scenario = ref.watch(_scenarioProvider);
    ref.watch(activeRollcallsProvider(null));
    final controller =
        ref.read(activeRollcallsProvider(null).notifier) as _PreviewRollcalls;
    final updated = controller.lastUpdatedAt;
    final updatedLabel = updated == null
        ? '下拉刷新查看所选场景'
        : '更新于 ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '退出预览',
                    onPressed: widget.onBack,
                    icon: const Icon(AppIcons.back),
                  ),
                  Expanded(
                    child: AppShellSelect<RollcallPreviewScenario>(
                      key: const ValueKey('rollcall-preview-scenario'),
                      subtitle: '开发预览 · 下拉刷新 · 模拟提交',
                      value: scenario,
                      items: RollcallPreviewScenario.values,
                      labelOf: (value) => value.label,
                      onChanged: (value) {
                        controller.selectScenario(value);
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: '重放场景',
                    onPressed: () {
                      controller.selectScenario(scenario);
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                    },
                    icon: const Icon(AppIcons.refresh),
                  ),
                  IconButton(
                    tooltip: '复制模拟二维码',
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: 'preview-qr'),
                      );
                      if (context.mounted) {
                        AppToast.show(context, '已复制模拟二维码，不向学校提交');
                      }
                    },
                    icon: const Icon(AppIcons.qr),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ShellTabScope(
                current: AppDestination.rollcall,
                retapEpoch: _retapEpoch,
                retapDestination: AppDestination.rollcall,
                child: PageScaffold(
                  title: '签到',
                  showHeader: false,
                  child: AppContentColumn(
                    child: MobileRollcallHome(
                      key: ValueKey(scenario),
                      controller: _scroll,
                      scope: null,
                      updatedLabel: updatedLabel,
                      accountMenu: RollcallAccountMenu(
                        masthead: true,
                        value: 0,
                        identities: const [],
                        ownerName: '预览同学',
                        onChanged: (_) {},
                      ),
                      onHistory: _otherPage,
                      onSettings: _otherPage,
                      onTimetable: _otherPage,
                      onHomework: _otherPage,
                      onOpenHomework: (_) => _otherPage(),
                      onRetryIdentity: () {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppMobileNav(
        current: AppDestination.rollcall,
        onSelect: (value) {
          if (value == AppDestination.rollcall) {
            setState(() => _retapEpoch++);
          } else {
            _otherPage();
          }
        },
        onSearch: _otherPage,
      ),
    );
  }
}

class _PreviewAdapter implements HttpClientAdapter {
  _PreviewAdapter(this.items, this.complete);
  final List<RollcallItem> Function() items;
  final void Function(int) complete;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    Object body;
    if (options.method == 'GET' && path == '/api/radar/rollcalls') {
      body = {'rollcalls': items().map((e) => e.toMonitorJson()).toList()};
    } else if (options.method == 'GET' &&
        RegExp(r'^/api/rollcall/900[123]/student_rollcalls$').hasMatch(path)) {
      body = {
        'student_rollcalls': [
          for (var i = 0; i < 40; i++)
            {'rollcall_status': i < 28 ? 'on_call_fine' : 'absent'},
        ],
      };
    } else if (options.method == 'PUT' &&
        RegExp(
          r'^/api/rollcall/900[123]/(answer|answer_number_rollcall|answer_qr_rollcall)$',
        ).hasMatch(path)) {
      complete(int.parse(path.split('/')[3]));
      body = <String, Object?>{};
    } else {
      // No socket fallback: unexpected requests stay inside this adapter.
      throw DioException(requestOptions: options, error: '独立预览未提供此数据');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
