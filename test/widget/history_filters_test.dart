import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

const _longTitle = '人工智能技术基础与跨学科应用专题研究（全英文教学与实验实践课程）';
CourseRollcallRecord _record(
  String id,
  String title,
  String event,
  String type,
  String status,
) => CourseRollcallRecord(
  courseId: id,
  courseTitle: title,
  rollcallId: event,
  rollcallTime: DateTime(2026, 10, 21, 10),
  typeLabel: type,
  signedStatus: status,
  platformStatus: '',
  detail: event,
);

class _History extends CourseHistoryNotifier {
  String? lastManualCourse;
  @override
  Future<List<CourseRollcallRecord>> build() async => [
    _record('a', _longTitle, '已签记录', '二维码签到', '已签到'),
    _record('a', _longTitle, '未签记录', '数字签到', '未签到'),
    _record('b', '线性代数', '另一课程', '二维码签到', '已签到'),
  ];
  @override
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
    String? courseId,
  }) async {
    if (reason == EnsureFreshReason.pullToRefresh) lastManualCourse = courseId;
  }
}

class _DatedHistory extends _History {
  @override
  Future<List<CourseRollcallRecord>> build() async {
    final now = DateTime.now();
    return [
      CourseRollcallRecord(
        courseId: 'a',
        courseTitle: '本学期课程',
        rollcallId: 'current',
        rollcallTime: DateTime(now.year, now.month, now.day - 6),
        typeLabel: '数字',
        signedStatus: '未签到',
        platformStatus: '',
      ),
      CourseRollcallRecord(
        courseId: 'a',
        courseTitle: '本学期课程',
        rollcallId: 'previous',
        rollcallTime: DateTime(now.year, now.month, now.day - 29),
        typeLabel: '数字',
        signedStatus: '已签到',
        platformStatus: '',
      ),
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('pulling filtered history requests only the selected course', (
    tester,
  ) async {
    final history = _History();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          courseHistoryProvider.overrideWith(() => history),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-course-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(history.lastManualCourse, 'b');
  });
  testWidgets(
    'menu counts follow other filters while the trigger stays compact',
    (tester) async {
      tester.view.physicalSize = const Size(384, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            courseHistoryProvider.overrideWith(_History.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HistoryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final status = find.byKey(const ValueKey('history-status-filter'));
      final course = find.byKey(const ValueKey('history-course-filter'));
      final type = find.byKey(const ValueKey('history-type-filter'));
      expect(find.text('签到次数'), findsNothing);
      expect(
        find.byKey(const ValueKey('history-recent-timeline')),
        findsNothing,
      );
      expect(find.text('全部状态'), findsOneWidget);
      await tester.tap(status);
      await tester.pumpAndSettle();
      void expectOption(int index, String label, int count) {
        final option = find.byKey(ValueKey('shell-select-option-$index'));
        expect(
          find.descendant(of: option, matching: find.text(label)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: option, matching: find.text('($count)')),
          findsOneWidget,
        );
      }

      expectOption(0, '全部状态', 3);
      expectOption(2, '已签到', 2);
      expectOption(1, '未签到', 1);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(
        tester
            .renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(const ValueKey('shell-select-option-2')),
                matching: find.text('已签到'),
              ),
            )
            .didExceedMaxLines,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
      await tester.pumpAndSettle();
      expect(find.text('未签记录'), findsOneWidget);
      expect(find.text('已签记录'), findsNothing);
      await tester.tap(course);
      await tester.pumpAndSettle();
      expectOption(2, '线性代数', 0);
      await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
      await tester.pumpAndSettle();
      await tester.tap(status);
      await tester.pumpAndSettle();
      expectOption(0, '全部状态', 2);
      expectOption(2, '已签到', 1);
      await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
      await tester.pumpAndSettle();
      expect(find.text('已签记录'), findsOneWidget);
      await tester.tap(type);
      await tester.pumpAndSettle();
      expectOption(1, '数字签到', 0);
      expectOption(3, '二维码签到', 1);
      await tester.tap(find.byKey(const ValueKey('shell-select-option-0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rolling 7 and 30 day filters can be reset without custom dates',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            courseHistoryProvider.overrideWith(_DatedHistory.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HistoryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('history-date-filter'));
      expect(find.byTooltip('全部时间'), findsNothing);
      expect(find.byTooltip('全部状态'), findsNothing);
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.byTooltip('7天内'), findsNothing);
      expect(find.text('自选日期'), findsNothing);
      expect(find.text('本周'), findsNothing);
      expect(find.text('本月'), findsNothing);
      await tester.tap(find.text('7天内'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('7天内'), findsNothing);
      expect(find.text('已签到'), findsNothing);
      expect(find.text('未签到'), findsOneWidget);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('30天内'));
      await tester.pumpAndSettle();
      expect(find.text('已签到'), findsOneWidget);
      expect(find.text('未签到'), findsOneWidget);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部时间'));
      await tester.pumpAndSettle();
      expect(find.text('已签到'), findsOneWidget);
      expect(find.text('未签到'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 384.0, 900.0, 1440.0]) {
    testWidgets('three filters fit $width and combine with long course names', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            courseHistoryProvider.overrideWith(_History.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HistoryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dateLabel = find.descendant(
        of: find.byKey(const ValueKey('history-date-filter')),
        matching: find.text('全部时间'),
      );
      expect(
        tester.renderObject<RenderParagraph>(dateLabel).didExceedMaxLines,
        isFalse,
      );
      final status = find.byKey(const ValueKey('history-status-filter'));
      final type = find.byKey(const ValueKey('history-type-filter'));
      final course = find.byKey(const ValueKey('history-course-filter'));
      expect(
        tester.getSize(status).width,
        closeTo(tester.getSize(course).width, .01),
      );
      expect(tester.getTopLeft(status).dy, tester.getTopLeft(course).dy);
      expect(tester.getTopLeft(type).dy, tester.getTopLeft(course).dy);

      await tester.tap(course);
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('shell-select-option-1'));
      expect(
        option,
        findsOneWidget,
        reason: 'course choices must be deduplicated',
      );
      final menu = tester.getRect(option);
      expect(menu.left, greaterThanOrEqualTo(0));
      expect(menu.right, lessThanOrEqualTo(width));
      expect(menu.width, lessThanOrEqualTo(240));
      final menuText = tester.widget<Text>(
        find.descendant(of: option, matching: find.byType(Text)).first,
      );
      expect(menuText.maxLines, 1);
      expect(menuText.overflow, TextOverflow.ellipsis);
      final countLabel = find.descendant(
        of: option,
        matching: find.text('(2)'),
      );
      expect(countLabel, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(countLabel).didExceedMaxLines,
        isFalse,
      );
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('另一课程'), findsNothing);
      final selected = tester.widget<Text>(
        find.descendant(of: course, matching: find.byType(Text)).first,
      );
      expect(selected.maxLines, 1);
      expect(selected.overflow, TextOverflow.ellipsis);
      expect(find.text('已签记录'), findsOneWidget);
      expect(find.text('未签记录'), findsOneWidget);

      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
      await tester.pumpAndSettle();
      expect(find.text('已签记录'), findsNothing);
      expect(find.text('未签记录'), findsOneWidget);
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
      await tester.pumpAndSettle();
      expect(find.text('无匹配记录'), findsOneWidget);

      await tester.tap(course);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shell-select-option-0')));
      await tester.pumpAndSettle();
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shell-select-option-0')));
      await tester.pumpAndSettle();
      expect(find.text('另一课程'), findsOneWidget);
      expect(find.text('已签记录'), findsOneWidget);
      expect(find.text('未签记录'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
