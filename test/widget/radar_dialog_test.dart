import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import '../fixtures/preview_fonts.dart';

const _item = RollcallItem(
  rollcallId: 91,
  courseTitle: '工程伦理与工程实践中的责任和专业判断',
  createdByName: '预览老师',
  type: RollcallType.radar,
  status: 'on_call',
  rollcallStatus: 'on_call',
  isExpired: false,
  scored: false,
  raw: {'course_id': 9},
);
final _screen = GlobalKey();

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    setIdentity(9101);
  }
  void setIdentity(int id) => state = AuthState(
    status: AuthStatus.signedIn,
    profile: UserProfile(id: id, name: '测试同学'),
  );
}

class _Lists extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? id) async => [_item];
  @override
  Future<void> refresh({bool manual = true}) async {}
}

class _Adapter implements HttpClientAdapter {
  int submissions = 0, status = 400;
  Object body = {'error_code': 'radar_out_of_rollcall_scope'};
  RequestOptions? submitted;
  Completer<void>? gate;
  bool offline = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT') {
      submissions++;
      submitted = options;
      await gate?.future;
      if (offline) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final icons = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/radar-dialog-cache',
          ).create(recursive: true)).absolute.path,
        );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.dismiss);

  Future<ProviderContainer> open(
    WidgetTester tester,
    _Adapter adapter, {
    double width = 1100,
    bool dark = false,
    String college = '能源学院',
    double scale = 1,
    bool rejectedPreset = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await AcademicScheduleStore.write(
      9101,
      AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime(2026, 11, 3),
        studentCollege: college,
        rows: const [],
      ),
    );
    await CourseCatalogStore.write(
      9101,
      CourseCatalogSnapshot(
        fetchedAt: DateTime(2026, 11, 3),
        courses: [
          CatalogCourse(
            id: '9',
            title: _item.courseTitle,
            timetables: {
              2: [
                TimetableSlot(
                  sequence: 3,
                  endSequence: 4,
                  start: DateTime(2000, 1, 3, 10),
                  end: DateTime(2000, 1, 3, 12),
                ),
              ],
            },
          ),
        ],
      ),
    );
    if (rejectedPreset) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'course_radar_defaults_9101',
        jsonEncode({
          'id:9': CourseRadarPref(
            courseId: '9',
            courseTitle: _item.courseTitle,
            latitude: 24.5,
            longitude: 118.2,
            userConfigured: true,
          ).toJson(),
        }),
      );
    }
    final memory = SecureStore.memory();
    final repo = RollcallRepository(
      identity: DeviceIdentity(memory),
      http: TronHttpClient(
        store: memory,
        dio: Dio()..httpClientAdapter = adapter,
        rateLimiter: RateLimiter(minInterval: Duration.zero),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        radarMeetingClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 3, 11),
        ),
        activeRollcallsProvider.overrideWith(_Lists.new),
        rollcallRepositoryForProvider.overrideWith((ref, id) => repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: _screen,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: width < 600
                  ? TargetPlatform.android
                  : TargetPlatform.windows,
            ),
            home: const Scaffold(body: RollcallListPage(embedded: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, rejectedPreset ? '签到' : '选择位置'),
    );
    await tester.pumpAndSettle();
    if (rejectedPreset) {
      expect(find.text('签到位置不匹配'), findsOneWidget);
      await tester.tap(find.text('重新选择'));
      await tester.pumpAndSettle();
    }
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(MapPickPanel), findsOneWidget);
    expect(
      tester
          .widget<RollcallAnswerPage>(find.byType(RollcallAnswerPage))
          .mapDialog,
      isTrue,
    );
    return container;
  }

  Future<void> pick(WidgetTester tester, LatLng point) async {
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), point);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['CAPTURE_RADAR_UI'] != '1') return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_screen),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/radar-interaction-review').create(recursive: true);
      await File(
        'build/radar-interaction-review/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [390.0, 1100.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'map dialog retries location rejection then completes card $width dark=$dark',
        (tester) async {
          final adapter = _Adapter();
          final container = await open(
            tester,
            adapter,
            width: width,
            dark: dark,
          );
          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          expect(map.mapController!.camera.center, Campus.xiangan.center);
          expect(
            tester
                .widget<FilledButton>(find.widgetWithText(FilledButton, '签到'))
                .onPressed,
            isNull,
          );
          expect(adapter.submissions, 0);
          await pick(tester, const LatLng(24.605, 118.314));
          expect(find.text('24.60500, 118.31400'), findsOneWidget);
          await capture(tester, 'picker-$width-$dark');
          final beforePan = map.mapController!.camera.center;
          await tester.drag(find.byType(FlutterMap), const Offset(-40, 20));
          await tester.pumpAndSettle();
          expect(map.mapController!.camera.center, isNot(beforePan));
          adapter.gate = Completer<void>();
          await tester.tap(find.widgetWithText(FilledButton, '签到'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(adapter.submissions, 1);
          expect(
            tester.widget<MapPickPanel>(find.byType(MapPickPanel)).busy,
            isTrue,
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) => widget is IconButton && widget.tooltip == '取消',
                  ),
                )
                .onPressed,
            isNull,
          );
          adapter.gate!.complete();
          await tester.pumpAndSettle();
          expect(find.text('签到位置不匹配'), findsOneWidget);
          await capture(tester, 'failure-$width-$dark');
          await tester.tap(find.text('重新选择'));
          await tester.pumpAndSettle();
          expect(find.byType(MapPickPanel), findsOneWidget);
          expect(find.text('24.60500, 118.31400'), findsOneWidget);
          adapter.status = 200;
          adapter.body = {};
          await pick(tester, const LatLng(24.606, 118.315));
          await tester.tap(find.widgetWithText(FilledButton, '签到'));
          await tester.pumpAndSettle();
          expect(adapter.submissions, 2);
          expect(find.byType(Dialog), findsNothing);
          expect(find.text('已签到'), findsOneWidget);
          expect(
            container
                .read(activeRollcallsProvider(null))
                .requireValue
                .single
                .isAnswered,
            isTrue,
          );
          final remembered = container
              .read(courseRadarDefaultsProvider.notifier)
              .forCourse(courseId: '9', meetingKey: '2:3-4:600-720');
          expect(remembered!.latitude, 24.606);
          await capture(tester, 'success-$width-$dark');
          AppToast.dismiss();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final college in ['法学院', '创意与创新学院']) {
    testWidgets('college $college sets map campus without submitting', (
      tester,
    ) async {
      final adapter = _Adapter();
      await open(tester, adapter, college: college);
      final campus = college == '法学院' ? Campus.siming : Campus.zhangzhou;
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center,
        campus.center,
      );
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(adapter.submissions, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'rejected preset opens a fresh campus picker and does not resubmit on entry',
    (tester) async {
      final adapter = _Adapter();
      await open(tester, adapter, rejectedPreset: true);
      expect(adapter.submissions, 1);
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center,
        Campus.xiangan.center,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '签到'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(find.text('选择位置'), findsOneWidget);
      expect(adapter.submissions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320px large text keeps coordinates, sign-in and cancel reachable',
    (tester) async {
      final adapter = _Adapter();
      await open(tester, adapter, width: 320, dark: true, scale: 1.3);
      await pick(tester, const LatLng(24.605, 118.314));
      await capture(tester, 'picker-320-large');
      expect(
        tester.getRect(find.widgetWithText(FilledButton, '签到')).bottom,
        lessThan(800),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(adapter.submissions, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a late success after account change cannot update or remember the old task',
    (tester) async {
      final adapter = _Adapter()
        ..status = 200
        ..gate = Completer<void>();
      final container = await open(tester, adapter);
      await pick(tester, const LatLng(24.605, 118.314));
      await tester.tap(find.widgetWithText(FilledButton, '签到'));
      await tester.pumpAndSettle();
      expect(adapter.submissions, 1);
      (container.read(authControllerProvider.notifier) as _Auth).setIdentity(
        9102,
      );
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        container
            .read(activeRollcallsProvider(null))
            .requireValue
            .single
            .isAnswered,
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('success_')), isEmpty);
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'network failure is not described as a wrong location and can cancel',
    (tester) async {
      final adapter = _Adapter()..offline = true;
      await open(tester, adapter);
      await pick(tester, const LatLng(24.605, 118.314));
      await tester.tap(find.widgetWithText(FilledButton, '签到'));
      await tester.pumpAndSettle();
      expect(find.text('签到位置不匹配'), findsNothing);
      expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('已签到'), findsNothing);
      expect(adapter.submissions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
