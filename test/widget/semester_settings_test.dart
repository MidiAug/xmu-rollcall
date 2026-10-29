import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/schedule/academic_mapping_page.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/semester_settings_page.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    switchTo(1);
  }
  void switchTo(int uid) {
    state = AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: uid, name: '测试'),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final font = Platform.environment['SETTINGS_UI_FONT'];
    if (font == null) return;
    await (FontLoader(
      'SemesterUi',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            Platform.environment['SETTINGS_UI_ICONS']!,
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  Future<void> seed() => AcademicScheduleStore.write(
    1,
    AcademicSchedule(
      term: '20261',
      monday: DateTime(2026, 9, 7),
      fetchedAt: DateTime.now(),
      rows: [],
    ),
  );

  Future<void> choose14(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('choose-first-monday')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14').last);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  }

  for (final scenario in [(384.0, 1.3, false), (960.0, 1.0, true)]) {
    testWidgets('first Monday shows source, saves and restores at $scenario', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(scenario.$1, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      var theme = scenario.$3 ? AppTheme.dark() : AppTheme.light();
      if (Platform.environment['SETTINGS_UI_FONT'] != null) {
        theme = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'SemesterUi'),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'SemesterUi',
              ),
            ),
          ),
        );
      }
      final key = GlobalKey();
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: const SemesterSettingsPage(userId: 1, ownerId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('默认校历'), findsOneWidget);
      expect(find.text('2026年9月7日'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-first-monday')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await SemesterPreferences.read(1, '20261'), isNull);
      expect(container.read(academicRevisionProvider), 0);
      await choose14(tester);
      expect(await SemesterPreferences.read(1, '20261'), DateTime(2026, 9, 14));
      expect(find.text('手动设置'), findsOneWidget);
      expect(container.read(academicRevisionProvider), 1);
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_SEMESTER_UI'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('.tools/semester-ui').create(recursive: true);
          await File(
            '.tools/semester-ui/settings-${scenario.$1.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(await SemesterPreferences.read(1, '20261'), isNull);
      expect(find.text('默认校历'), findsOneWidget);
      expect(container.read(academicRevisionProvider), 2);
    });
  }
  testWidgets(
    'account switching while date picker is open prevents a stale save',
    (tester) async {
      await seed();
      final auth = _Auth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => auth)],
          child: const MaterialApp(
            home: SemesterSettingsPage(userId: 1, ownerId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-first-monday')));
      await tester.pumpAndSettle();
      auth.switchTo(2);
      await tester.tap(find.text('14').last);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(await SemesterPreferences.read(1, '20261'), isNull);
      expect(await SemesterPreferences.read(2, '20261'), isNull);
      expect(find.text('日期未保存，请重试'), findsOneWidget);
    },
  );
  testWidgets(
    'associations prioritize unresolved courses and fold automatic matches',
    (tester) async {
      await AcademicScheduleStore.write(
        1,
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: DateTime.now(),
          rows: [
            {'KCDM': 'C', 'BJDM': 'A', 'KCMC': '教务课程', 'BJMC': 'A班'},
          ].map(AcademicCourseRow.fromJson).toList(),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
          child: const MaterialApp(
            home: AcademicMappingPage(
              userId: 1,
              courses: [
                CatalogCourse(
                  id: 'matched',
                  title: '已关联课',
                  academicMatched: true,
                  academicGroup: 'C/A',
                ),
                CatalogCourse(id: 'pending', title: '待关联课'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('关联课程'), findsOneWidget);
      expect(find.byType(AppShellSelect<String>), findsOneWidget);
      expect(find.text('已关联（1）'), findsOneWidget);
      expect(find.text('已关联课'), findsNothing);
      await tester.tap(find.text('已关联（1）'));
      await tester.pumpAndSettle();
      expect(find.text('已关联课'), findsOneWidget);
      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShellSelect<String>), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
