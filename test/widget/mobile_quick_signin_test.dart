import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';
import 'package:xmu_rollcall/features/location/location_validation_store.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  void switchOwner() {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 2, name: '另一个账号'),
    );
  }

  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

class _Lists extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? id) async => [];
  @override
  Future<void> refresh({bool manual = true}) async {}
}

class _Network extends Fake implements RollcallRepository {
  int submissions = 0, countReads = 0;
  double? latitude;
  Completer<AnswerResult>? pending;
  Completer<void>? beforeSendGate;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async =>
      AttendanceCount(++countReads, 40);
  @override
  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
    String? opId,
  }) async {
    expect(numberCode, '1234');
    submissions++;
    return pending?.future ?? const AnswerResult(ok: true);
  }

  @override
  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String? opId,
    Future<void> Function()? beforeSend,
  }) async {
    await beforeSendGate?.future;
    await beforeSend?.call();
    submissions++;
    this.latitude = latitude;
    return pending?.future ?? const AnswerResult(ok: true);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.dismiss);
  for (final mode in [
    'number',
    'configured',
    'success',
    'mapped',
    'outside',
    'missing',
    'rejected',
    'switched',
    'changed',
  ]) {
    testWidgets('Android tap submits $mode only when a reliable input exists', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final course = CatalogCourse(
        id: '9',
        title: '测试课',
        timetables: {
          1: [
            TimetableSlot(
              sequence: 3,
              endSequence: 4,
              start: DateTime(2000, 1, 3, 10, 10),
              end: DateTime(2000, 1, 3, 11, 50),
              classroom: '学武楼A404',
            ),
          ],
        },
      );
      final meeting = courseMeetingLabels(course).keys.single;
      if (mode == 'success') {
        await CourseCatalogStore.write(
          1,
          CourseCatalogSnapshot(fetchedAt: DateTime.now(), courses: [course]),
        );
      }
      final point = CourseRadarPref(
        courseTitle: '测试课',
        courseId: '9',
        latitude: 24.5,
        longitude: 118.2,
        userConfigured: mode != 'success',
        meetingKey: mode == 'success' ? meeting : '',
        obtainedVia: 'map',
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
      if (mode == 'configured' ||
          mode == 'rejected' ||
          mode == 'switched' ||
          mode == 'changed') {
        await prefs.setString(
          'course_radar_defaults_1',
          jsonEncode({'id:9': point.toJson()}),
        );
      } else if (mode == 'success') {
        await prefs.setString(
          courseRadarMeetingPreferenceKey(1, null, point),
          jsonEncode(point.toJson()),
        );
      }
      if (mode == 'rejected') await recordLocationIssue(1, 1, point);
      final network = _Network()..pending = Completer<AnswerResult>();
      if (mode == 'switched' || mode == 'changed') {
        network.beforeSendGate = Completer<void>();
      }
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(
            SecureStore.memory({SecureStore.keyUserId: '1'}),
          ),
          authControllerProvider.overrideWith((ref) => _Auth()),
          activeRollcallsProvider.overrideWith(_Lists.new),
          rollcallRepositoryForProvider(null).overrideWithValue(network),
        ],
      );
      addTearDown(container.dispose);
      final item = RollcallItem(
        rollcallId: 17,
        courseTitle: '测试课',
        createdByName: '教师',
        type: mode == 'number' ? RollcallType.number : RollcallType.radar,
        status: 'absent',
        rollcallStatus: 'on_call',
        isExpired: false,
        scored: false,
        numberCode: mode == 'number' ? '1234' : null,
        raw: const {'course_id': 9, 'created_at': '2026-10-26T10:30:00'},
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: RollcallTaskCard(
                item: item,
                meeting: mode == 'mapped' || mode == 'outside'
                    ? CampusMeeting(
                        id: '9',
                        title: '测试课',
                        room: '学武楼A404',
                        start: DateTime(
                          2026,
                          10,
                          26,
                          mode == 'outside' ? 14 : 10,
                          10,
                        ),
                        end: DateTime(
                          2026,
                          10,
                          26,
                          mode == 'outside' ? 15 : 11,
                          50,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(network.submissions, 0);
      if (mode == 'number') expect(find.text('1234'), findsOneWidget);
      if (mode == 'configured' || mode == 'success') {
        expect(find.text('24.50000, 118.20000'), findsOneWidget);
      }
      if (mode == 'missing' || mode == 'rejected' || mode == 'outside') {
        expect(find.text('需补充签到位置'), findsOneWidget);
      }
      await tester.tap(find.text('去签到'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      if (mode == 'switched' || mode == 'changed') {
        expect(network.submissions, 0);
        if (mode == 'switched') {
          (container.read(authControllerProvider.notifier) as _Auth)
              .switchOwner();
        } else {
          await prefs.setString(
            'course_radar_defaults_1',
            jsonEncode({
              'id:9': {...point.toJson(), 'latitude': 24.6},
            }),
          );
        }
        network.beforeSendGate!.complete();
        await tester.pumpAndSettle();
        expect(
          network.submissions,
          0,
          reason:
              'An identity or coordinate change cancels the queued submission',
        );
      } else if (mode == 'missing' || mode == 'rejected' || mode == 'outside') {
        expect(network.submissions, 0);
        expect(find.byType(RollcallAnswerPage), findsOneWidget);
      } else {
        expect(network.submissions, 1);
        expect(find.byType(RollcallAnswerPage), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        final button = find.widgetWithText(FilledButton, '提交中…');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        network.pending!.complete(
          const AnswerResult(ok: true, message: '签到成功'),
        );
        await tester.pumpAndSettle();
        expect(network.submissions, 1);
        expect(
          find.widgetWithText(FilledButton, '已签到'),
          findsOneWidget,
          reason:
              'Server acknowledgement wins over a stale active-list snapshot',
        );
        expect(find.text('去签到'), findsNothing);
        expect(network.countReads, greaterThanOrEqualTo(2));
        final reads = network.countReads;
        AppToast.dismiss();
        await tester.pump(const Duration(seconds: 40));
        expect(
          network.countReads,
          reads,
          reason:
              'Completed attendance takes one final reading then stops polling',
        );
        if (mode != 'number' && mode != 'mapped') {
          expect(network.latitude, 24.5);
        }
      }
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
