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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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
      final container = ProviderContainer();
      addTearDown(container.dispose);
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
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.byType(MapPickPanel), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请填写地点备注'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(find.byType(TextField), '测试教室');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(MapPickPanel), findsNothing);
      expect(find.text('测试教室'), findsWidgets);
      final place = container.read(savedLocationsProvider).single;
      expect(place.latitude, kDefaultMapCenter.latitude);
      await tester.tap(find.text('测试教室').first);
      await tester.pumpAndSettle();
      expect(find.text('更新坐标'), findsOneWidget);
      await tester.tapAt(
        tester.getCenter(find.byType(MapPickPanel)) + const Offset(60, -30),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('更新坐标'));
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
        jsonDecode(prefs.getString('saved_radar_locations')!)[0]['latitude'],
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
            theme: AppTheme.light(),
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
