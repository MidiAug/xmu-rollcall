import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'owner'),
    );
  }
}

class _Repo extends Fake implements RollcallRepository {
  double? lat;
  double? lng;
  int calls = 0;
  @override
  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String? opId,
    Future<void> Function()? beforeSend,
  }) async {
    await beforeSend?.call();
    calls++;
    lat = latitude;
    lng = longitude;
    return const AnswerResult(ok: true, status: 200, message: '提交成功');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['CAPTURE_LOCATION_HEADER'] == '1') {
      await loadDesktopPreviewFonts();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/map-test-cache',
          ).create(recursive: true)).absolute.path,
        );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('mobile campus uses shared menu and keeps explicit selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screen = GlobalKey();
    Future<void> capture(String state) async {
      if (Platform.environment['CAPTURE_LOCATION_HEADER'] != '1') return;
      await tester.runAsync(() async {
        final image =
            await (screen.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/location-header-review').create(recursive: true);
        await File(
          'build/location-header-review/$state.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseRoomsProvider.overrideWithValue(const ['学武楼A404']),
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
          preferredCampusProvider.overrideWithValue(Campus.xiangan),
        ],
        child: RepaintBoundary(
          key: screen,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const SavedLocationsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<Campus>), findsNothing);
    expect(
      tester
          .widget<AppShellSelect<Campus>>(find.byType(AppShellSelect<Campus>))
          .value,
      Campus.xiangan,
    );
    final trigger = find.byType(AppToolbarChoice<Campus>);
    expect(tester.getSize(trigger).height, 48);
    expect(find.byType(AppSelectTrigger), findsNothing);
    await capture('list');
    await tester.tap(find.byKey(const ValueKey('managed-room-学武楼')));
    await tester.pumpAndSettle();
    expect(find.text('地点管理'), findsNothing);
    expect(find.text('地点列表'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-back-to-list')), findsNothing);
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final panel = tester.getRect(
      find.byKey(const ValueKey('map-building-inspector')),
    );
    expect(mapRect.left, 0);
    expect(mapRect.right, 384);
    expect(panel.left - mapRect.left, 16);
    expect(mapRect.right - panel.right, 16);
    expect(
      mapRect.bottom - panel.bottom,
      16 + MapAttributionControls.footerHeight,
    );
    await capture('map');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('地点管理'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('managed-room-学武楼')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('地点管理'), findsOneWidget);
    await tester.tap(find.byType(AppShellSelect<Campus>));
    await tester.pumpAndSettle();
    await capture('campus-sheet');
    await tester.tap(find.text('漳州校区'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppShellSelect<Campus>>(find.byType(AppShellSelect<Campus>))
          .value,
      Campus.zhangzhou,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('small map form keeps equal edges and scrolls above keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          courseRoomsProvider.overrideWithValue(const ['西部片区9号楼']),
          preferredCampusProvider.overrideWithValue(Campus.xiangan),
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SavedLocationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('managed-room-西部片区9号楼')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('map-place-inspector'));
    final clip = find
        .ancestor(of: panel, matching: find.byType(ClipRRect))
        .first;
    final bounds = tester.getRect(clip);
    final map = tester.getRect(find.byType(FlutterMap));
    expect(bounds.left - map.left, 16);
    expect(map.right - bounds.right, 16);
    expect(
      map.bottom - bounds.bottom,
      16 + MapAttributionControls.footerHeight,
    );
    expect(bounds.height, lessThanOrEqualTo(map.height - 32));
    final save = find.widgetWithText(FilledButton, '保存坐标');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(bounds.contains(tester.getCenter(save)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile add location keeps note above keyboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
        home: const MapPickPage(requireNote: true),
      ),
    );
    final note = find.byKey(const ValueKey('location-note-input'));
    await tester.tap(note);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(note).dy, lessThanOrEqualTo(544));
    await tester.enterText(note, '教室');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'desktop add and update location return to saved list and persist',
    (tester) async {
      await desktop(tester);
      final container = ProviderContainer(
        overrides: [
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
          courseRoomsProvider.overrideWithValue(const ['测试教室']),
        ],
      );
      addTearDown(container.dispose);
      await tester.runAsync(
        () => container.read(savedLocationsProvider.notifier).ready,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SavedLocationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CampusMap), findsOneWidget);
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('managed-room-测试教室')));
      await tester.pumpAndSettle();
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(24.4375, 118.098),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('managed-place-name'));
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).readOnly, isTrue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存坐标'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存坐标'))
            .onPressed,
        isNotNull,
      );
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存坐标'))
          .onPressed!;
      await tester.runAsync(() async => await Function.apply(save, const []));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('地点未能保存，请重试'), findsNothing);
      final place = container.read(savedLocationsProvider).single;
      await tester.ensureVisible(find.text('校正坐标'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('校正坐标'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CampusMap));
      await tester.pumpAndSettle();
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(24.4385, 118.098),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存校正'));
      await tester.pumpAndSettle();
      final update = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存校正'))
          .onPressed!;
      await tester.runAsync(() async => await Function.apply(update, const []));
      await tester.pumpAndSettle();
      final updatedLatitude = container
          .read(savedLocationsProvider)
          .single
          .latitude;
      expect(updatedLatitude, isNot(place.latitude));
      final restored = SavedLocationsController();
      addTearDown(restored.dispose);
      await tester.runAsync(() => restored.ready);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('saved_radar_locations_signed_out')!,
        )[0]['latitude'],
        updatedLatitude,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop course radar uses assist location, confirms once and remembers in correct scope',
    (tester) async {
      await desktop(tester);
      CourseRadarPref pref(double lat, String label) => CourseRadarPref(
        courseTitle: 'course',
        courseId: '7',
        latitude: lat,
        longitude: 118.2,
        obtainedVia: 'map',
        labelSnapshot: label,
        userConfigured: true,
      );
      SharedPreferences.setMockInitialValues({
        'course_radar_defaults_1': jsonEncode({
          'id:7': pref(24.4, 'owner room').toJson(),
        }),
        'course_radar_defaults_1_assist_2': jsonEncode({
          'id:7': pref(24.5, 'assist room').toJson(),
        }),
      });
      await CourseCatalogStore.write(
        2,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 26),
          rolesResolved: true,
          courses: const [CatalogCourse(id: '7', title: 'course')],
        ),
      );
      await CourseScheduleStore.write(2, '7', const [
        CourseMeeting(
          weekday: 1,
          first: 1,
          last: 3,
          startMinutes: 480,
          endMinutes: 630,
        ),
      ]);
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          radarMeetingClockProvider.overrideWithValue(
            () => DateTime(2026, 10, 26, 9),
          ),
          rollcallRepositoryForProvider.overrideWith((ref, id) {
            expect(id, 2);
            return repo;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RollcallAnswerPage(
              assistUserId: 2,
              item: RollcallItem(
                rollcallId: 10,
                courseTitle: 'course',
                createdByName: 'teacher',
                type: RollcallType.radar,
                status: 'on_call',
                rollcallStatus: 'on_call',
                isExpired: false,
                scored: false,
                raw: {'course_id': 7},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('assist room'), findsOneWidget);
      expect(find.text('owner room'), findsNothing);
      await tester.tap(find.text('设为本课位置，供自动签到使用'));
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      expect(
        container
            .read(courseRadarDefaultsForProvider(2).notifier)
            .forCourse(courseId: '7')!
            .userConfigured,
        true,
      );
      await tester.ensureVisible(find.text('用此位置签到'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('用此位置签到'));
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.tap(find.widgetWithText(FilledButton, '确认提交'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(repo.lat, 24.5);
      expect(repo.lng, 118.2);
      final remembered = container
          .read(courseRadarDefaultsForProvider(2).notifier)
          .forCourse(courseId: '7', meetingKey: '1:1-3:480-630');
      expect(remembered!.meetingKey, '1:1-3:480-630');
      expect(remembered.userConfigured, false);
      expect(
        container
            .read(courseRadarDefaultsForProvider(2).notifier)
            .forCourse(courseId: '7')
            ?.latitude,
        24.5,
      );
      final ownerDefaults = container.read(
        courseRadarDefaultsProvider.notifier,
      );
      await tester.runAsync(() => ownerDefaults.ready);
      expect(
        container
            .read(courseRadarDefaultsProvider.notifier)
            .forCourse(courseId: '7')
            ?.latitude,
        24.4,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
