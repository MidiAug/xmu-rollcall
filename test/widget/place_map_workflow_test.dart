import 'package:xmu_rollcall/features/location/location_validation_store.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

Future<void> capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  if (Platform.environment['CAPTURE_PLACE_UI'] != '1') return;
  await tester.runAsync(() async {
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('place-capture')),
    );
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await Directory(
      'build/place-ui-review',
    ).create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _IssueAuthRepo extends Fake implements AuthRepository {}

class _IssueAuth extends AuthController {
  _IssueAuth() : super(_IssueAuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试同学'),
    );
  }
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/map-test-cache',
          ).create(recursive: true)).absolute.path,
        );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (Platform.environment['CAPTURE_PLACE_UI'] == '1') {
      await loadDesktopPreviewFonts();
      await (FontLoader('MaterialIcons')..addFont(
            File(
              'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  test(
    'explicit places reload edits made while that account was selected',
    () async {
      final scope = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SecureStore.memory()),
          authControllerProvider.overrideWith((ref) => _IssueAuth()),
        ],
      );
      addTearDown(scope.dispose);
      var source = scope.read(savedLocationsForUserProvider(2));
      await scope.read(source.notifier).ready;
      scope.read(selectedRollcallAccountProvider.notifier).state = 2;
      await scope
          .read(savedLocationsProvider.notifier)
          .add(note: 'Assist place', latitude: 24.605, longitude: 118.313);
      scope.read(selectedRollcallAccountProvider.notifier).state = null;
      source = scope.read(savedLocationsForUserProvider(2));
      await scope.read(source.notifier).ready;
      expect(scope.read(source).single.note, 'Assist place');
      await scope.read(savedLocationsProvider.notifier).ready;
      expect(scope.read(savedLocationsProvider), isEmpty);
    },
  );

  testWidgets(
    'explicit assist timetable binds its own places without changing selection',
    (tester) async {
      final schedule = AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime.now(),
        rows: const [
          AcademicCourseRow(
            courseId: 'test',
            courseName: 'Assist course',
            room: '测试教学楼101',
            weekday: 1,
            firstPeriod: 1,
            lastPeriod: 2,
            startMinute: 480,
            endMinute: 540,
            weeks: {8},
          ),
        ],
      );
      await AcademicScheduleStore.write(2, schedule);
      final scope = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SecureStore.memory()),
          authControllerProvider.overrideWith((ref) => _IssueAuth()),
          academicTimetableProvider.overrideWith(
            (ref, uid) async => AcademicTimetableState(schedule: schedule),
          ),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CoursesPage(assistUserId: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scope.read(selectedRollcallAccountProvider), isNull);
      expect(scope.read(unmatchedRoomsProvider), isEmpty);
      await tester.tap(find.text('1 个上课地点未定位'));
      await tester.pumpAndSettle();
      final group = scope.read(coursePlaceGroupsForUserProvider(2)).single;
      expect(group.courses, ['Assist course']);
      await tester.tap(find.text(group.name).first);
      await tester.pumpAndSettle();
      tester.widget<CampusMap>(find.byType(CampusMap)).onTap!(
        const LatLng(24.605, 118.313),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存坐标'));
      await tester.pumpAndSettle();
      final assistPlaces = scope.read(
        scope.read(savedLocationsForUserProvider(2)),
      );
      expect(assistPlaces.single.note, group.name);
      expect(scope.read(savedLocationsProvider), isEmpty);
      expect(scope.read(selectedRollcallAccountProvider), isNull);
      expect(scope.read(unmatchedRoomsForUserProvider(2)), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [384.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'map completion and read-only homework at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scope = ProviderContainer(
            overrides: [
              campusCachedDataProvider.overrideWith(
                (ref) async => const CampusCachedData(),
              ),
              courseRoomsProvider.overrideWithValue([
                '学武楼（1号楼）C201',
                '西部片区9号楼108',
              ]),
              homeworkDetailProvider.overrideWith(
                (ref, key) async => HomeworkItem(
                  id: 1,
                  title: '第四周作业：程序设计基础',
                  courseName: 'C语言程序设计',
                  courseId: 3,
                  dueAt: DateTime(2026, 10, 29),
                  description: '<p>完成课本第四章练习，说明解题思路。</p><p>请阅读附件中的格式要求。</p>',
                  attachments: [
                    HomeworkAttachment(
                      name: '第四章练习.pdf',
                      size: 20480,
                      url: Uri.parse('https://lnt.xmu.edu.cn/example.pdf'),
                    ),
                  ],
                ),
              ),
            ],
          );
          addTearDown(scope.dispose);
          final theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: width < 600
                ? TargetPlatform.android
                : TargetPlatform.windows,
          );
          Future<void> show(Widget body) async {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: scope,
                child: MaterialApp(
                  theme: theme,
                  home: RepaintBoundary(
                    key: const ValueKey('place-capture'),
                    child: body,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await show(const SavedLocationsPage());
          expect(scope.read(preferredCampusProvider), Campus.xiangan);
          expect(find.text('待定位（1）'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          if (width >= 720) {
            expect(find.byType(CampusSelector), findsOneWidget);
            expect(
              tester.getTopLeft(find.byType(CampusSelector)).dy,
              lessThan(
                tester
                    .getTopLeft(
                      find.byKey(const ValueKey('managed-room-西部片区9号楼')),
                    )
                    .dy,
              ),
            );
          } else {
            expect(find.byType(AppShellSelect<Campus>), findsOneWidget);
          }
          expect(find.byTooltip('只看待补全'), findsNothing);
          expect(find.byTooltip('显示全部地点'), findsNothing);
          expect(find.byType(AppSegmentedControl<bool>), findsNothing);
          expect(find.byTooltip('添加地点'), findsNothing);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('managed-room-西部片区9号楼')))
                .height,
            width < 600 ? inInclusiveRange(68, 72) : lessThanOrEqualTo(60),
          );
          await capture(tester, 'map-$width-$dark');
          await tester.tap(find.byKey(const ValueKey('managed-room-西部片区9号楼')));
          await tester.pumpAndSettle();
          if (width < 720) {
            expect(
              find.byKey(const ValueKey('map-back-to-list')),
              findsNothing,
            );
            expect(find.text('地点列表'), findsOneWidget);
            expect(find.byTooltip('返回'), findsOneWidget);
          }
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('managed-place-name')),
                )
                .readOnly,
            isTrue,
          );
          expect(find.text('地点名称沿用教务或导入课表，请保持一致以便自动匹配。'), findsOneWidget);
          await capture(tester, 'map-edit-$width-$dark');
          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          map.options.onTap!(
            const TapPosition(Offset.zero, Offset.zero),
            const LatLng(24.606, 118.30),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('保存坐标'));
          await tester.tap(find.text('保存坐标'));
          await tester.pumpAndSettle();
          expect(scope.read(unmatchedRoomsProvider), isEmpty);
          expect(scope.read(savedLocationsProvider).single.note, '西部片区9号楼');
          await capture(tester, 'map-saved-$width-$dark');
          await show(
            const HomeworkDetailPage(seed: HomeworkItem(id: 1, title: '作业')),
          );
          expect(find.text('第四章练习.pdf'), findsOneWidget);
          expect(find.byTooltip('下载附件'), findsOneWidget);
          await capture(tester, 'homework-$width-$dark');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'building overview expands regions while a region keeps exact coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
            preferredCampusProvider.overrideWithValue(Campus.xiangan),
            courseRoomsProvider.overrideWithValue(const [
              '学武楼A404',
              '学武楼B101',
              '学武楼C201',
              '坤銮楼A201',
              '坤銮楼B201',
              '坤銮楼C201',
            ]),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RepaintBoundary(
              key: ValueKey('place-capture'),
              child: SavedLocationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('managed-room-学武楼')), findsOneWidget);
      expect(find.byKey(const ValueKey('managed-room-学武楼 A区')), findsNothing);
      expect(find.text('A区'), findsNothing);
      final cluster = tester
          .widget<MarkerLayer>(
            find.byWidgetPredicate(
              (w) =>
                  w is MarkerLayer &&
                  w.markers.any((m) => m.width != 44 && m.width < 110),
            ),
          )
          .markers
          .first;
      expect(cluster.alignment, Alignment.center);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-building-学武楼')),
          matching: find.text('3'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-building-学武楼')),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 225 && w.child != null,
        ),
        findsOneWidget,
      );
      await capture(tester, 'building-overview');
      await tester.tap(find.byKey(const ValueKey('map-building-学武楼')));
      await tester.pumpAndSettle();
      final inspector = find.byKey(const ValueKey('map-building-inspector'));
      expect(inspector, findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('暂无匹配课程'), findsOneWidget);
      await tester.tap(
        find.descendant(of: inspector, matching: find.byTooltip('关闭地点详情')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(24.6055024, 118.3138315), 18.3);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-place-学武楼 B区')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-building-学武楼')), findsNothing);
      await capture(tester, 'building-expanded');
      final before = controller.camera;
      await tester.tap(find.byKey(const ValueKey('map-place-学武楼 B区')));
      await tester.pumpAndSettle();
      expect(controller.camera.center, before.center);
      expect(controller.camera.zoom, before.zoom);
      final selectedMap = tester.widget<CampusMap>(find.byType(CampusMap));
      expect(selectedMap.point, isNull);
      expect(selectedMap.selectedPlaceId, isNotNull);
      expect(find.byIcon(Icons.location_on), findsNothing);
      final selectedLabel = find.byKey(const ValueKey('map-place-学武楼 B区'));
      final primary = Theme.of(
        tester.element(selectedLabel),
      ).colorScheme.primary;
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: selectedLabel,
                matching: find.byType(Material),
              ),
            )
            .color,
        primary,
      );
      expect(find.text('暂无匹配课程'), findsOneWidget);
      expect(find.text('补充区域位置'), findsNothing);
      await capture(tester, 'building-region-selected');
      controller.move(controller.camera.center, 16);
      await tester.pumpAndSettle();
      final selectedBuilding = find.byKey(const ValueKey('map-building-学武楼'));
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: selectedBuilding,
                matching: find.byType(Material),
              ),
            )
            .color,
        primary,
      );
      await capture(tester, 'building-selected-collapsed');
      await tester.tap(find.byTooltip('关闭地点详情'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CampusMap>(find.byType(CampusMap)).selectedPlaceId,
        isNull,
      );
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: selectedBuilding,
                matching: find.byType(Material),
              ),
            )
            .color,
        isNot(primary),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [384.0, 960.0]) {
    testWidgets('building panels show matched courses at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
            preferredCampusProvider.overrideWithValue(Campus.xiangan),
            courseRoomsProvider.overrideWithValue(const []),
            coursePlaceGroupsProvider.overrideWithValue(const [
              CoursePlaceGroup('学武楼 A区', ['学武楼A404'], ['专业英语', '工程伦理']),
              CoursePlaceGroup('坤銮楼 A区', ['坤銮楼A206'], ['课程示例']),
              CoursePlaceGroup('学武楼 C区', ['学武楼C201'], ['高级人工智能']),
              CoursePlaceGroup('西部片区2号楼', ['西部片区2号楼108'], ['软件测试', '科技论文写作']),
            ]),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RepaintBoundary(
              key: ValueKey('place-capture'),
              child: SavedLocationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('managed-room-文宣楼')), findsNothing);
      expect(find.byKey(const ValueKey('managed-room-西部片区4号楼')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('managed-room-学信楼')));
      await tester.pumpAndSettle();
      final cluster = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer).first)
          .markers
          .singleWhere(
            (m) => m.child.key == const ValueKey('map-building-坤銮楼'),
          );
      expect(cluster.point.latitude, closeTo(24.60559845, .0000001));
      expect(cluster.point.longitude, closeTo(118.3127415, .0000001));
      final panel = find.byKey(const ValueKey('map-building-inspector'));
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('软件测试')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('科技论文写作')),
        findsOneWidget,
      );
      expect(find.text('补充区域位置'), findsNothing);
      await capture(tester, 'building-courses-$width');
      if (width < 720) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('managed-room-学武楼')));
      await tester.pumpAndSettle();
      for (final title in ['A区', 'C区', '专业英语', '工程伦理', '高级人工智能']) {
        expect(
          find.descendant(of: panel, matching: find.text(title)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: panel, matching: find.text('B区')),
        findsNothing,
      );
      expect(tester.getSize(panel).height, lessThan(250));
      expect(find.text('补充区域位置'), findsNothing);
      await capture(tester, 'building-region-courses-$width');
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(24.605991, 118.313890), 18.3);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-place-学武楼 C区')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: panel, matching: find.text('高级人工智能')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('专业英语')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [384.0, 960.0]) {
    testWidgets(
      'rejected place is prioritized, corrected and unlocked for existing bindings at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final point = CourseRadarPref(
          courseId: '7',
          courseTitle: '课程一',
          meetingKey: 'm',
          placeId: 'xmu:teaching:xuewu-a',
          labelSnapshot: '学武楼 A区',
          latitude: 24.604970,
          longitude: 118.313776,
          userConfigured: true,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          courseRadarPreferencesKey(1, null)!,
          jsonEncode({'id:7': point.toJson()}),
        );
        await recordLocationIssue(1, 1, point);
        final scope = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _IssueAuth()),
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
            preferredCampusProvider.overrideWithValue(Campus.xiangan),
            coursePlaceGroupsProvider.overrideWithValue(const [
              CoursePlaceGroup('学武楼 A区', ['学武楼A404'], ['课程一']),
              CoursePlaceGroup('新教学楼', ['新教学楼101'], ['课程二']),
            ]),
          ],
        );
        addTearDown(scope.dispose);
        await scope.read(savedLocationsProvider.notifier).ready;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const RepaintBoundary(
                key: ValueKey('place-capture'),
                child: SavedLocationsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('待校正（1）'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('待校正（1）')).dy,
          lessThan(tester.getTopLeft(find.text('待定位（1）')).dy),
        );
        await capture(tester, 'binding-errors-$width');
        await tester.tap(find.byKey(const ValueKey('managed-room-学武楼')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('校正A区位置'));
        await tester.pumpAndSettle();
        final name = tester.widget<TextField>(
          find.byKey(const ValueKey('managed-place-name')),
        );
        expect(name.readOnly, isTrue);
        expect(name.controller!.text, '学武楼 A区');
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        map.options.onTap!(
          const TapPosition(Offset.zero, Offset.zero),
          const LatLng(24.6051, 118.3139),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'binding-correction-$width');
        await tester.tap(find.text('保存坐标'));
        await tester.pumpAndSettle();
        expect(await readLocationIssues(1, 1), isEmpty);
        final saved = await readAutomaticRadarLocation(
          ownerId: 1,
          assistUserId: null,
          courseId: '7',
          meetingKey: 'm',
        );
        expect(saved!.latitude, 24.6051);
        expect(saved.placeId, scope.read(savedLocationsProvider).single.id);
        expect(saved.userConfigured, isTrue);
        expect(find.text('待校正（1）'), findsNothing);
        expect(
          teachingPlaces
              .singleWhere((p) => p.id == 'xmu:teaching:xuewu-a')
              .latitude,
          24.6050038,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'a rejected legacy point without a classroom is corrected as its own course binding',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const point = CourseRadarPref(
        courseId: '7',
        courseTitle: '旧绑定课程',
        meetingKey: 'm',
        latitude: 24.605,
        longitude: 118.313,
        userConfigured: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        courseRadarPreferencesKey(1, null)!,
        jsonEncode({'id:7': point.toJson()}),
      );
      await recordLocationIssue(1, 1, point);
      final scope = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _IssueAuth()),
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
          preferredCampusProvider.overrideWithValue(Campus.xiangan),
          coursePlaceGroupsProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(scope.dispose);
      await scope.read(savedLocationsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SavedLocationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('待校正（1）'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('managed-room-旧绑定课程上课地点')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('managed-place-name')))
            .readOnly,
        isTrue,
      );
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(24.6052, 118.3132),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存坐标'));
      await tester.pumpAndSettle();
      expect(await readLocationIssues(1, 1), isEmpty);
      final saved = await readAutomaticRadarLocation(
        ownerId: 1,
        assistUserId: null,
        courseId: '7',
        meetingKey: 'm',
      );
      expect(saved!.latitude, 24.6052);
      expect(saved.userConfigured, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'map controls consume taps and a draft preserves pan, zoom and equal insets',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
            courseRoomsProvider.overrideWithValue(const ['西部片区9号楼108']),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RepaintBoundary(
              key: ValueKey('place-capture'),
              child: SavedLocationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mapFinder = find.byType(CampusMap);
      final mapRect = tester.getRect(mapFinder);
      final hint = tester.getRect(find.byKey(const ValueKey('map-idle-hint')));
      expect(hint.left - mapRect.left, closeTo(12, .1));
      expect(mapRect.bottom - hint.bottom, closeTo(12, .1));
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('managed-room-西部片区9号楼')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(24.6068, 118.3118), 20);
      await tester.pumpAndSettle();
      final before = controller.camera;
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).maxNativeZoom,
        18,
      );
      expect(before.zoom, 20);
      await tester.tap(find.byTooltip('地图来源'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('map-attribution-panel')),
        findsOneWidget,
      );
      expect(tester.widget<CampusMap>(mapFinder).point, isNull);
      final controls = tester.getRect(find.byType(MapAttributionControls));
      expect(controls.top - mapRect.top, closeTo(12, .1));
      expect(mapRect.right - controls.right, closeTo(12, .1));
      await tester.tap(find.byTooltip('flutter_map'));
      await tester.pumpAndSettle();
      expect(tester.widget<CampusMap>(mapFinder).point, isNull);
      expect(find.byKey(const ValueKey('map-attribution-panel')), findsNothing);
      await tester.tapAt(mapRect.topLeft + const Offset(100, 140));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final point = tester.widget<CampusMap>(mapFinder).point!;
      final after = controller.camera;
      expect(after.center.latitude, closeTo(before.center.latitude, 1e-10));
      expect(after.center.longitude, closeTo(before.center.longitude, 1e-10));
      expect(after.zoom, before.zoom);
      final inspector = tester.getRect(
        find.byKey(const ValueKey('map-place-inspector')),
      );
      expect(mapRect.right - inspector.right, closeTo(12, .1));
      expect(mapRect.bottom - inspector.bottom, closeTo(12, .1));
      final coordinates = tester.widget<SelectableText>(
        find.byKey(const ValueKey('managed-place-coordinates')),
      );
      expect(
        coordinates.data,
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
      );
      await tester.tap(find.byTooltip('地图来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-attribution-panel')));
      await tester.pumpAndSettle();
      expect(tester.widget<CampusMap>(mapFinder).point, point);
      expect(controller.camera.center, after.center);
      expect(controller.camera.zoom, after.zoom);
      await capture(tester, 'map-viewport-draft');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'academic course opens and returns from a map within one dialog',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final course = CatalogCourse(
        id: 'academic:test',
        title: '课程示例',
        location: '学武楼C201',
        timetables: {
          1: [
            TimetableSlot(
              sequence: 5,
              endSequence: 6,
              start: DateTime(2000, 1, 1, 14, 30),
              end: DateTime(2000, 1, 1, 16, 10),
              classroom: '学武楼C201',
            ),
          ],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: TimetableGridView(courses: [course])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程示例').first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final flow = find.byKey(const ValueKey('course-detail-flow'));
      final compactHeight = tester.getSize(flow).height;
      expect(
        tester
            .getSize(find.byKey(const ValueKey('course-location-map-link')))
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const ValueKey('course-location-map-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final expandingHeight = tester.getSize(flow).height;
      await tester.pumpAndSettle();
      final mapHeight = tester.getSize(flow).height;
      expect(expandingHeight, greaterThan(compactHeight));
      expect(expandingHeight, lessThan(mapHeight));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CampusMap), findsOneWidget);
      expect(find.byType(CampusSelector), findsNothing);
      final map = tester.widget<CampusMap>(find.byType(CampusMap));
      expect(map.zoom, 17);
      expect(map.places, isEmpty);
      expect(map.point, isNotNull);
      await tester.tap(find.byTooltip('返回课程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final collapsingHeight = tester.getSize(flow).height;
      expect(collapsingHeight, lessThan(mapHeight));
      expect(collapsingHeight, greaterThan(compactHeight));
      await tester.pumpAndSettle();
      expect(find.byType(CampusMap), findsNothing);
      expect(find.byTooltip('关闭课程详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
