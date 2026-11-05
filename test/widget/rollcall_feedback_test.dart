import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_panel.dart';
import 'package:xmu_rollcall/app/refresh_feedback.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';

class Repo extends Fake implements AuthRepository {}

class AttendanceRepo extends Fake implements RollcallRepository {
  int calls = 0;
  int submissions = 0;
  @override
  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
    String? opId,
  }) async {
    submissions++;
    return const AnswerResult(ok: true);
  }

  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async {
    calls++;
    return const AttendanceCount(2, 40);
  }
}

class Auth extends AuthController {
  Auth() : super(Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class Seed extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? id) async => rows;
  static List<RollcallItem> rows = [];
  @override
  Future<void> refresh({bool manual = true}) async {}
}

RollcallItem item({
  bool expired = false,
  bool answered = false,
  String? code,
  bool withCourse = false,
  RollcallType type = RollcallType.number,
}) => RollcallItem(
  rollcallId: 1,
  courseTitle: '测试课程',
  createdByName: '老师',
  type: type,
  status: answered ? 'on_call_fine' : 'on_call',
  rollcallStatus: 'on_call',
  isExpired: expired,
  scored: false,
  numberCode: code,
  raw: withCourse ? const {'course_id': 9} : const {},
);

void main() {
  tearDown(AppToast.dismiss);
  testWidgets('card update time stays distinct from the detection status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = item(code: '1234');
    Seed.rows = [row];
    final repo = AttendanceRepo();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => Auth()),
        activeRollcallsProvider.overrideWith(Seed.new),
        rollcallRepositoryForProvider(null).overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeRollcallsProvider(null).future);
    container.read(activeRollcallsProvider(null).notifier).lastUpdatedAt =
        DateTime(2026, 10, 30, 10, 31).toUtc();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: RollcallTaskCard(item: row, mobileSummary: '今日无课'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('更新于 10:31'), findsOneWidget);
    expect(find.text('今日无课'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 960.0]) {
    for (final type in [
      RollcallType.number,
      RollcallType.radar,
      RollcallType.qrcode,
    ]) {
      testWidgets(
        '$type replaces its entry with one completed action at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = AttendanceRepo();
          Seed.rows = [item(type: type, code: '1234')];
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => Auth()),
                activeRollcallsProvider.overrideWith(Seed.new),
                rollcallRepositoryForProvider(null).overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: Scaffold(body: RollcallListPage(embedded: true)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final entryLabel = switch (type) {
            RollcallType.qrcode => '扫码',
            RollcallType.radar => '选择位置',
            _ => '签到',
          };
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, entryLabel),
                )
                .onPressed,
            isNotNull,
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(RollcallListPage)),
          );
          if (type == RollcallType.number) {
            await tester.tap(find.widgetWithText(FilledButton, entryLabel));
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsNothing);
            expect(repo.submissions, 1);
          }
          final notifier = container.read(
            activeRollcallsProvider(null).notifier,
          );
          notifier.debugSeed([item(type: type, answered: true, code: '1234')]);
          await tester.pumpAndSettle();
          expect(find.text('已签到'), findsOneWidget);
          expect(find.text(entryLabel), findsNothing);
          expect(find.text('手动输入'), findsNothing);
          final completed = find.widgetWithText(FilledButton, '已签到');
          expect(tester.widget<FilledButton>(completed).onPressed, isNull);
          final calls = repo.calls;
          final submissions = repo.submissions;
          await tester.tap(completed);
          await tester.pump(const Duration(seconds: 30));
          expect(repo.calls, calls);
          expect(repo.submissions, submissions);
          expect(find.byType(AttendanceCountRow), findsOneWidget);
          expect(
            tester
                .widget<AttendanceCountRow>(find.byType(AttendanceCountRow))
                .completed,
            isTrue,
          );
          notifier.debugSeed([
            item(type: type, answered: true, expired: true, code: '1234'),
          ]);
          await tester.pumpAndSettle();
          expect(find.text('已签到'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'completed card keeps the final attendance count and code without polling',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => null,
          );
      final repo = AttendanceRepo();
      Seed.rows = [item(code: '1234', withCourse: true)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => Auth()),
            activeRollcallsProvider.overrideWith(Seed.new),
            rollcallRepositoryForProvider(null).overrideWithValue(repo),
            sessionPriorProvider.overrideWith(
              (ref, id) async => const SessionPriorState(unscoped: true),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RollcallListPage(embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceCountRow), findsOneWidget);
      expect(find.byType(SessionPriorPanel), findsNothing);
      expect(repo.calls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RollcallListPage)),
      );
      container.read(activeRollcallsProvider(null).notifier).debugSeed([
        item(answered: true, code: '1234', withCourse: true),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceCountRow), findsOneWidget);
      expect(
        tester
            .widget<AttendanceCountRow>(find.byType(AttendanceCountRow))
            .completed,
        isTrue,
      );
      expect(
        repo.calls,
        2,
        reason: 'Completion reads one final attendance count',
      );
      expect(find.byType(SessionPriorPanel), findsNothing);
      expect(find.text('1234'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 2);
      await tester.tap(find.text('1234'));
      await tester.pumpAndSettle();
      expect(find.text('已复制签到码'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'missing number code offers manual entry; expired task disables actions',
    (tester) async {
      Future<void> show(RollcallItem row) async {
        Seed.rows = [row];
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              authControllerProvider.overrideWith((ref) => Auth()),
              activeRollcallsProvider.overrideWith(Seed.new),
              rollcallRepositoryForProvider(
                null,
              ).overrideWithValue(AttendanceRepo()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: RollcallListPage(embedded: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(item());
      final manual = find.widgetWithText(FilledButton, '手动输入');
      expect(tester.widget<FilledButton>(manual).onPressed, isNotNull);
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.text('输入签到码'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await show(item(expired: true));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '已结束'))
            .onPressed,
        isNull,
      );
      await show(item(expired: true, type: RollcallType.qrcode));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '已结束'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('refresh failure keeps content and exposes retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RefreshFeedback(
            error: StateError('offline'),
            updatedAt: DateTime(2026, 10, 11, 10),
            onRetry: () => retries++,
            child: const Text('缓存课程'),
          ),
        ),
      ),
    );
    expect(find.text('缓存课程'), findsOneWidget);
    expect(find.textContaining('显示上次数据'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
  testWidgets('quick action can be activated with keyboard', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppQuietPill(onTap: () => calls++, child: const Text('开始检测')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });
}
