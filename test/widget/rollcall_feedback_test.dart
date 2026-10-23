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
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id) async {
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
          final entryLabel = type == RollcallType.qrcode
              ? '扫码签到'
              : type == RollcallType.radar
              ? '选择位置'
              : '一键签到';
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
          await tester.tap(completed);
          await tester.pump(const Duration(seconds: 30));
          expect(repo.calls, calls);
          expect(find.byType(AttendanceCountRow), findsNothing);
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
    'signed card removes decision aids and stops polling but keeps code',
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
      expect(find.byType(SessionPriorPanel), findsOneWidget);
      expect(repo.calls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RollcallListPage)),
      );
      container.read(activeRollcallsProvider(null).notifier).debugSeed([
        item(answered: true, code: '1234', withCourse: true),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceCountRow), findsNothing);
      expect(find.byType(SessionPriorPanel), findsNothing);
      expect(find.text('1234'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 1);
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
      expect(find.text('手动输入'), findsOneWidget);
      expect(find.text('输入签到码'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '输入签到码'))
            .onPressed,
        isNotNull,
      );
      await show(item(expired: true));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '已结束'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '手动输入'))
            .onPressed,
        isNull,
      );
      await show(item(expired: true, type: RollcallType.qrcode));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '扫码签到'))
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
