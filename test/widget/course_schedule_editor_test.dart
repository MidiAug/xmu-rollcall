import 'dart:async';
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
  classroom: '教学楼 A201',
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
  testWidgets('missing schedule badge opens editor even when grid is empty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('补全安排'));
    await tester.pumpAndSettle();
    expect(find.text('待补全安排'), findsOneWidget);
    await tester.tap(find.text('无排课课程'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseScheduleEditor), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      await (FontLoader('Microsoft YaHei')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          ))
          .load();
    }
    final icons = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0),
    (width: 384.0, dark: true, scale: 1.0),
    (width: 320.0, dark: false, scale: 1.3),
  ]) {
    testWidgets(
      'schedule edit fits $scenario, saves independent meetings and guards drafts',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final captureKey = GlobalKey();
        final gate = Completer<void>();
        List<CourseMeeting>? saved;
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: (scenario.dark ? AppTheme.dark() : AppTheme.light())
                  .copyWith(
                    platform: scenario.width > 600
                        ? TargetPlatform.windows
                        : TargetPlatform.android,
                    textTheme:
                        (scenario.dark ? AppTheme.dark() : AppTheme.light())
                            .textTheme
                            .apply(fontFamily: 'Microsoft YaHei'),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'Microsoft YaHei',
                        ),
                      ),
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'Microsoft YaHei',
                        ),
                      ),
                    ),
                  ),
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
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_SCHEDULE_UI'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final dir = await Directory(
              'build/desktop-ui-review',
            ).create(recursive: true);
            await File(
              '${dir.path}/schedule-${scenario.width}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.enterText(
          find.widgetWithText(TextField, '教学楼 A201'),
          '教学楼 B302',
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.text('教学楼 B302'), findsOneWidget);
        if (scenario.width <= 384) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.text('保存'));
        await tester.pump();
        expect(saved!.single.classroom, '教学楼 B302');
        expect(saved!.single.last, 7);
        expect(find.text('保存中…'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
              .onPressed,
          isNull,
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invalid times do not save; adding and deleting meetings is reversible',
    (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CourseScheduleEditor(
            course: const CatalogCourse(id: 'c', title: '课程'),
            onSave: (_) async {
              saves++;
            },
          ),
        ),
      );
      await tester.tap(find.text('添加一次上课'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.textContaining('请填写有效'), findsOneWidget);
      await tester.tap(find.byTooltip('删除本次安排'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    },
  );
}
