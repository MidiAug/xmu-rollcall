import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/course_schedule_editor.dart';

const meeting = CourseMeeting(
  weekday: 1,
  first: 5,
  last: 7,
  startMinutes: 870,
  endMinutes: 1020,
  classroom: '原地点',
);

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试同学'),
    );
  }
}

class _Catalog extends CourseCatalogNotifier {
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: DateTime(2026, 10, 26),
    rolesResolved: true,
    courses: const [CatalogCourse(id: 'c', title: '无排课课程')],
  );
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      savedRadarLocationsKey: jsonEncode([
        SavedLocation(
          id: 'B',
          note: '教学楼 B302',
          latitude: 24.5,
          longitude: 118.2,
          createdAt: DateTime(2026),
        ).toJson(),
      ]),
    }),
  );
  setUpAll(() async {
    for (final font in {
      'Microsoft YaHei': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons':
          'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      if (File(font.value).existsSync()) {
        await (FontLoader(font.key)..addFont(
              File(font.value).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    }
  });
  testWidgets('missing schedule chip opens editor even when grid is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          courseCatalogProvider.overrideWith(_Catalog.new),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CoursesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无课表安排'), findsOneWidget);
    await tester.tap(find.text('补全安排'));
    await tester.pumpAndSettle();
    expect(find.text('待完善'), findsOneWidget);
    await tester.tap(find.text('无排课课程'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseScheduleEditor), findsOneWidget);
    expect(find.text('08:00–09:40  ·  第 1–2 节'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0),
    (width: 384.0, dark: true, scale: 1.0),
    (width: 320.0, dark: false, scale: 1.3),
  ]) {
    testWidgets(
      'schedule selects count and saved place, fits $scenario and guards drafts',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final gate = Completer<void>();
        List<CourseMeeting>? saved;
        Map<String, SavedLocation>? points;
        var theme = scenario.dark ? AppTheme.dark() : AppTheme.light();
        theme = theme.copyWith(
          platform: scenario.width > 600
              ? TargetPlatform.windows
              : TargetPlatform.android,
          textTheme: theme.textTheme.apply(fontFamily: 'Microsoft YaHei'),
          textButtonTheme: TextButtonThemeData(
            style: theme.textButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: theme.filledButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      child: const Text('编辑安排'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => CourseScheduleEditor(
                          course: const CatalogCourse(
                            id: 'c',
                            title: '大学生职业素养养成',
                            localMeetings: [meeting],
                          ),
                          onSave: (m) async {
                            saved = m;
                            await gate.future;
                          },
                          onSaveLocations: (m) async {
                            points = m;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('编辑安排'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('上 3 节'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('上 2 节').last);
        await tester.pumpAndSettle();
        expect(find.text('14:30–16:10  ·  第 5–6 节'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('meeting-location-0')));
        await tester.pumpAndSettle();
        expect(find.byType(LocationPickerContent), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        await tester.tap(find.text('教学楼 B302'));
        await tester.pumpAndSettle();
        expect(find.text('教学楼 B302'), findsOneWidget);
        expect(find.byType(LocationPickerContent), findsNothing);
        if (Platform.environment['CAPTURE_SCHEDULE_UI'] == '1') {
          await tester.runAsync(() async {
            final img =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final dir = await Directory(
              'build/desktop-ui-review',
            ).create(recursive: true);
            await File(
              '${dir.path}/schedule-${scenario.width}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.text('教学楼 B302'), findsOneWidget);
        expect(saved, isNull);
        expect(points, isNull);
        await tester.tap(find.text('保存'));
        await tester.pump();
        expect(saved!.single.classroom, '教学楼 B302');
        expect(saved!.single.first, 5);
        expect(saved!.single.last, 6);
        expect(saved!.single.startMinutes, 870);
        expect(saved!.single.endMinutes, 970);
        expect(find.text('保存中…'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
              .onPressed,
          isNull,
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(points!.keys.single, '1:5-6:870-970');
        expect(points!.values.single.id, 'B');
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('overlapping meetings cannot save; deleting is reversible', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CourseScheduleEditor(
            course: const CatalogCourse(id: 'c', title: '课程'),
            onSave: (_) async {
              saves++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('添加一次上课'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('同一天的上课安排不能重叠'), findsOneWidget);
    await tester.tap(find.byTooltip('删除本次安排').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除本次安排'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inline add location and period bounds persist through the real schedule page',
    (tester) async {
      tester.view.physicalSize = const Size(384, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 26),
          rolesResolved: true,
          courses: const [CatalogCourse(id: 'c', title: '无排课课程')],
        ),
      );
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const CoursesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('补全安排'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('无排课课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 1 节'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('第 11 节').last);
      await tester.tap(find.text('第 11 节').last);
      await tester.pumpAndSettle();
      expect(find.text('上 1 节'), findsOneWidget);
      expect(find.text('21:00–21:45  ·  第 11–11 节'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meeting-location-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加地点'));
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('location-note-input'));
      await tester.tap(note);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(note).dy, lessThanOrEqualTo(544));
      await tester.enterText(note, '新上课地点');
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并使用'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final defaults = container.read(courseRadarDefaultsProvider.notifier);
      expect(defaults.forCourse(courseId: 'c'), isNull);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final stored = (await CourseScheduleStore.read(1, 'c')).single;
      expect(stored.first, 11);
      expect(stored.last, 11);
      expect(stored.classroom, '新上课地点');
      expect(
        defaults
            .forCourse(courseId: 'c', meetingKey: '1:11-11:1260-1305')!
            .labelSnapshot,
        '新上课地点',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
