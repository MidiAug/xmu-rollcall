import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_identity_card.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/settings/course_schedule_editor.dart';

const identity = AssistIdentity(
  userId: 2,
  displayName: '协助同学',
  kind: AssistCredentialKind.session,
);

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '本人'),
    );
  }
}

ProviderContainer scope() => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith((ref) => _Auth()),
    assistControllerProvider.overrideWith(
      (ref) => AssistController(
        ref,
        bootstrap: false,
        initial: const AssistUiState(ready: true, identities: [identity]),
      ),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (Platform.environment['CAPTURE_MEETING_UI'] != '1') return;
    for (final font in {
      'MeetingUi': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons':
          'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
            font.key,
          )..addFont(File(font.value).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'meeting multi-select saves only selected assist meetings, and cancellation writes nothing (dark: $dark)',
      (tester) async {
        tester.view.physicalSize = Size(dark ? 320 : 960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = scope();
        addTearDown(container.dispose);
        final current = ValueNotifier('mon');
        addTearDown(current.dispose);
        var choice = 'A';
        final boundary = GlobalKey();
        var theme = dark ? AppTheme.dark() : AppTheme.light();
        if (Platform.environment['CAPTURE_MEETING_UI'] == '1') {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'MeetingUi'),
            listTileTheme: theme.listTileTheme.copyWith(
              titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'MeetingUi',
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'MeetingUi',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'MeetingUi',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(dark ? 1.3 : 1)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ValueListenableBuilder<String>(
                    valueListenable: current,
                    builder: (context, key, _) => CourseLocationSetting(
                      courseId: '7',
                      courseTitle: '课程',
                      assistUserId: 2,
                      meetingKey: key,
                      meetings: const {'mon': '周一 第1–3节', 'wed': '周三 第5–6节'},
                      pickLocation: (selectedId, initial) async =>
                          SavedLocation(
                            id: choice,
                            note: choice,
                            latitude: 24.5,
                            longitude: 118.2,
                            createdAt: DateTime(2026),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> choose() async {
          await tester.tap(
            find.byKey(const ValueKey('course-location-picker')),
          );
          await tester.pumpAndSettle();
        }

        await choose();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        current.value = 'wed';
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('沿用同课默认地点'), findsOneWidget);
        choice = 'B';
        await choose();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        await choose();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        final prefs = container.read(
          courseRadarDefaultsForProvider(2).notifier,
        );
        expect(
          prefs.forCourse(courseId: '7', meetingKey: 'mon')!.labelSnapshot,
          'A',
        );
        expect(
          prefs.forCourse(courseId: '7', meetingKey: 'wed')!.labelSnapshot,
          'B',
        );
        choice = 'C';
        await choose();
        if (Platform.environment['CAPTURE_MEETING_UI'] == '1') {
          AppToast.dismiss();
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final directory = await Directory(
              '.tools/meeting-location-ui',
            ).create(recursive: true);
            await File(
              '${directory.path}/${dark ? 'mobile-dark' : 'desktop-light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.tap(find.text('周一 第1–3节'));
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(
          prefs.forCourse(courseId: '7', meetingKey: 'mon')!.labelSnapshot,
          'C',
        );
        expect(
          prefs.forCourse(courseId: '7', meetingKey: 'wed')!.labelSnapshot,
          'C',
        );
        expect(
          container
              .read(courseRadarDefaultsProvider.notifier)
              .forCourse(courseId: '7'),
          isNull,
        );
        expect(tester.takeException(), isNull);
        AppToast.dismiss();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'imported identity menu opens reused timetable and missing schedule editor without switching rollcall account',
    (tester) async {
      await CourseCatalogStore.write(
        2,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 26),
          rolesResolved: true,
          courses: const [CatalogCourse(id: '7', title: '协助课程')],
        ),
      );
      final container = scope();
      addTearDown(container.dispose);
      final selected = container.read(selectedRollcallAccountProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AssistIdentityCard(identity: identity)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看课表'));
      await tester.pumpAndSettle();
      expect(find.byType(CoursesPage), findsOneWidget);
      expect(
        tester.widget<CoursesPage>(find.byType(CoursesPage)).assistUserId,
        2,
      );
      await tester.tap(find.text('补全安排'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('协助课程'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseScheduleEditor), findsOneWidget);
      expect(container.read(selectedRollcallAccountProvider), selected);
      expect(tester.takeException(), isNull);
    },
  );
}
