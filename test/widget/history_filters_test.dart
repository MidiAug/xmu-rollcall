import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

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

class _PeriodHistory extends _History {
  @override
  Future<List<CourseRollcallRecord>> build() async {
    final now = DateTime.now();
    CourseRollcallRecord row(
      String id,
      String course,
      int days,
      String status,
      String type,
    ) => CourseRollcallRecord(
      courseId: course,
      courseTitle: course == 'a' ? '高等数学' : '线性代数',
      rollcallId: id,
      rollcallTime: DateTime(now.year, now.month, now.day - days),
      typeLabel: type,
      signedStatus: status,
      platformStatus: '',
    );
    final recent = row('recent', 'a', 1, '未签到', '二维码签到');
    return [
      recent,
      recent,
      row('old', 'a', 12, '已签到', '数字签到'),
      row('older', 'b', 35, '已签到', '二维码签到'),
      row('-', 'a', 0, '无签到', '未知'),
    ];
  }
}

class _ProjectionHistory extends _History {
  _ProjectionHistory({this.includeUndated = false});

  final bool includeUndated;

  @override
  Future<List<CourseRollcallRecord>> build() async {
    final day = DateTime.now();
    CourseRollcallRecord row(String course, String id, int hour, String type) =>
        CourseRollcallRecord(
          courseId: course,
          courseTitle: course == 'a' ? _longTitle : '另一课程',
          rollcallId: id,
          rollcallTime: DateTime(day.year, day.month, day.day, hour),
          typeLabel: type,
          signedStatus: '已签到',
          platformStatus: '',
        );
    final first = row('a', 'first', 8, '二维码');
    return [
      first,
      first,
      row('a', 'second', 10, '数字'),
      row('b', 'first', 9, '雷达'),
      if (includeUndated)
        const CourseRollcallRecord(
          courseId: 'd',
          courseTitle: '缺少时间的记录',
          rollcallId: 'undated',
          rollcallTime: null,
          typeLabel: '数字',
          signedStatus: '未知',
          platformStatus: '',
        ),
      CourseRollcallRecord(
        courseId: 'c',
        courseTitle: '尚无记录的课程',
        rollcallId: '-',
        // A placeholder's persisted date is not an observed attendance time.
        rollcallTime: DateTime(2001, 1, 1),
        typeLabel: '-',
        signedStatus: '无签到',
        platformStatus: '',
      ),
    ];
  }
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final (width, scale, dark, undated) in [
    (320.0, 1.3, true, false),
    (960.0, 1.0, false, false),
    (960.0, 1.0, false, true),
  ]) {
    testWidgets(
      'history timeline uses event identities and readable labels at $width undated=$undated',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                courseHistoryProvider.overrideWith(
                  () => _ProjectionHistory(includeUndated: undated),
                ),
              ],
              child: MaterialApp(
                theme: desktopCaptureTheme(
                  dark ? AppTheme.dark() : AppTheme.light(),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const HistoryPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await captureDesktopUi(
          tester,
          'history-events-${width.toInt()}${undated ? '-undated' : ''}',
        );
        for (final label in ['全部状态', '全部类型', '全部课程']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'each primary filter must keep its role readable',
          );
        }
        final first = find.byKey(const ValueKey('a_first_已签到'));
        final second = find.byKey(const ValueKey('a_second_已签到'));
        final otherCourse = find.byKey(const ValueKey('b_first_已签到'));
        expect(first, findsOneWidget);
        expect(second, findsOneWidget);
        expect(otherCourse, findsOneWidget);
        expect(find.text('08:00'), findsOneWidget);
        expect(find.text('09:00'), findsOneWidget);
        expect(find.text('10:00'), findsOneWidget);
        final now = DateTime.now();
        final exactTime = DateTime(
          now.year,
          now.month,
          now.day,
          8,
        ).toString().substring(0, 19);
        expect(find.text(exactTime), findsNothing);
        expect(find.byTooltip(exactTime), findsOneWidget);
        expect(
          tester.getTopLeft(second).dy,
          lessThan(tester.getTopLeft(otherCourse).dy),
        );
        expect(
          tester.getTopLeft(otherCourse).dy,
          lessThan(tester.getTopLeft(first).dy),
        );
        expect(find.text('尚无记录的课程'), findsOneWidget);
        expect(find.text('2001年1月1日 周一'), findsNothing);
        if (undated) {
          final header = find.text('时间未提供');
          final row = find.byKey(const ValueKey('d_undated_未知'));
          expect(header, findsOneWidget);
          expect(row, findsOneWidget);
          expect(
            tester.getTopLeft(header).dy,
            lessThan(tester.getTopLeft(row).dy),
          );
          expect(
            tester.getTopLeft(row).dy,
            lessThan(tester.getTopLeft(find.text('暂无签到记录的课程')).dy),
          );
        } else {
          expect(find.text('时间未提供'), findsNothing);
        }
        final title = tester.widget<Text>(find.text(_longTitle).first);
        expect(title.maxLines, 1);
        final type = tester.renderObject<RenderParagraph>(
          find.text('二维码').first,
        );
        expect(type.didExceedMaxLines, isFalse);
        if (width < 600) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(_longTitle).first,
          );
          expect(paragraph.didExceedMaxLines, isTrue);
          await tester.longPress(find.text(_longTitle).first);
          await tester.pumpAndSettle();
          expect(find.text(_longTitle), findsNWidgets(3));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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

  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0),
    (width: 960.0, dark: true, scale: 1.0),
    (width: 384.0, dark: false, scale: 1.0),
    (width: 320.0, dark: true, scale: 1.3),
  ]) {
    testWidgets(
      'time counts respect other filters and ignore their own selection at $scenario',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                courseHistoryProvider.overrideWith(_PeriodHistory.new),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: desktopCaptureTheme(
                  scenario.dark ? AppTheme.dark() : AppTheme.light(),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: const HistoryPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final date = find.byKey(const ValueKey('history-date-filter'));
        final status = find.byKey(const ValueKey('history-status-filter'));
        if (scenario.width >= 600) {
          expect(tester.getTopLeft(date).dy, tester.getTopLeft(status).dy);
          expect(
            tester.getSize(date).width,
            closeTo(tester.getSize(status).width, .01),
          );
        } else {
          expect(
            tester.getTopLeft(date).dy,
            lessThan(tester.getTopLeft(status).dy),
          );
        }
        final label =
            '${scenario.width.toInt()}-${scenario.dark ? 'dark' : 'light'}';
        await captureDesktopUi(tester, 'history-four-filters-$label');
        void counts(List<int> expected) {
          for (var i = 0; i < expected.length; i++) {
            expect(
              find.descendant(
                of: find.byKey(ValueKey('shell-select-option-$i')),
                matching: find.text('(${expected[i]})'),
              ),
              findsOneWidget,
            );
          }
        }

        await tester.tap(date);
        await tester.pumpAndSettle();
        counts([3, 1, 2]);
        await captureDesktopUi(tester, 'history-time-counts-$label');
        await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        counts([3, 1, 2]);
        await tester.tap(find.byKey(const ValueKey('shell-select-option-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-course-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        counts([2, 1, 2]);
        await tester.tap(find.byKey(const ValueKey('shell-select-option-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-type-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-3')));
        await tester.pumpAndSettle();
        await tester.tap(status);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        counts([0, 0, 0]);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final width in [320.0, 384.0, 900.0, 1440.0]) {
    testWidgets(
      'responsive filters fit $width and combine with long course names',
      (tester) async {
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
        final date = find.byKey(const ValueKey('history-date-filter'));
        if (width >= 600) {
          expect(tester.getTopLeft(date).dy, tester.getTopLeft(status).dy);
          expect(
            tester.getSize(date).width,
            closeTo(tester.getSize(status).width, .01),
          );
        } else {
          expect(
            tester.getTopLeft(date).dy,
            lessThan(tester.getTopLeft(status).dy),
          );
        }
        expect(
          tester.getSize(status).width,
          closeTo(tester.getSize(course).width, .01),
        );
        final fields = [status, type, course].map(tester.getRect).toList();
        for (var i = 0; i < fields.length; i++) {
          expect(fields[i].left, greaterThanOrEqualTo(16));
          expect(fields[i].right, lessThanOrEqualTo(width - 16));
          if (i == 0) continue;
          expect(fields[i].top, greaterThanOrEqualTo(fields[i - 1].top));
          expect(fields[i].overlaps(fields[i - 1]), isFalse);
        }
        for (final label in ['全部状态', '全部类型', '全部课程']) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
          );
        }

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
        expect(
          menu.width,
          width < 680 ? closeTo(width - 32, 1) : lessThanOrEqualTo(240),
        );
        final menuText = tester.widget<Text>(
          find.descendant(of: option, matching: find.byType(Text)).first,
        );
        if (width < 680) {
          expect(menuText.maxLines, isNull);
        } else {
          expect(menuText.maxLines, 1);
          expect(menuText.overflow, TextOverflow.ellipsis);
        }
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
      },
    );
  }
}
