import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'dart:ui' as ui;
import 'package:xmu_rollcall/app/chrome.dart';
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
  initializeDesktopUiCapture();
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
        for (final label
            in width < 600 ? ['全部', '类型与时间', '全部课程'] : ['全部', '全部类型', '全部课程']) {
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

  for (final scenario in [
    (width: 960.0, scale: 1.0, dark: false),
    (width: 960.0, scale: 1.3, dark: true),
    (width: 384.0, scale: 1.0, dark: false),
    (width: 320.0, scale: 1.3, dark: true),
    (width: 320.0, scale: 2.0, dark: false),
  ]) {
    testWidgets(
      'status, course, type and period use the same deduplicated records $scenario',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 1000);
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
        Finder row(String id) => find.byKey(ValueKey(id));
        expect(row('a_recent_未签到'), findsOneWidget);
        expect(row('a_old_已签到'), findsOneWidget);
        expect(row('b_older_已签到'), findsOneWidget);
        final status = find.byKey(const ValueKey('history-status-filter'));
        expect(status, findsOneWidget);
        final course = find.byKey(const ValueKey('history-course-filter'));
        final width = scenario.width;
        for (final target in [status, course]) {
          expect(tester.getRect(target).left, greaterThanOrEqualTo(16));
          expect(tester.getRect(target).right, lessThanOrEqualTo(width - 16));
        }
        Future<void> secondary({String? type, String? period}) async {
          if (width < 600) {
            await tester.tap(
              find.byKey(const ValueKey('history-secondary-filters')),
            );
            await tester.pumpAndSettle();
            if (type != null) {
              await tester.tap(find.widgetWithText(AppFilterChoice, type));
            }
            if (period != null) {
              Focus.of(tester.element(find.text(period))).requestFocus();
              await tester.pump();
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            }
            await tester.pumpAndSettle();
            if (period == '7天内') {
              final choice = find.widgetWithText(AppFilterChoice, period!);
              final mouse = await tester.createGesture(
                kind: ui.PointerDeviceKind.mouse,
              );
              await mouse.addPointer(location: const Offset(1, 1));
              await mouse.moveTo(tester.getCenter(choice));
              await tester.pumpAndSettle();
              final p = AppPalette.of(tester.element(choice));
              expect(
                tester.widget<Text>(find.text(period)).style!.color,
                p.ink,
              );
              final rect = tester.getRect(choice);
              await mouse.down(rect.center);
              await tester.pumpAndSettle();
              expect(tester.getRect(choice), rect);
              await mouse.moveTo(const Offset(1, 1));
              await mouse.up();
              await tester.pumpAndSettle();
              expect(tester.widget<AppFilterChoice>(choice).selected, isTrue);
              await mouse.removePointer();
              await tester.pumpAndSettle();
            }
            await captureDesktopUi(
              tester,
              'history-sheet-${width.toInt()}-${scenario.dark}',
            );
            await tester.tap(find.text('应用筛选'));
            await tester.pumpAndSettle();
          } else {
            if (type != null) {
              await tester.tap(
                find.byKey(const ValueKey('history-type-filter')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.widgetWithText(AppMenuOption, type));
              await tester.pumpAndSettle();
            }
            if (period != null) {
              await tester.tap(
                find.byKey(const ValueKey('history-date-filter')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.widgetWithText(AppMenuOption, period));
              await tester.pumpAndSettle();
            }
          }
        }

        await captureDesktopUi(
          tester,
          'history-r25-${width.toInt()}-${scenario.dark}',
        );
        if (width >= 600 && scenario.scale == 1.0) {
          expect(tester.getSize(status).height, 36.0);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('history-desktop-filters')))
                .height,
            36.0,
          );
        } else if (width < 600 && scenario.scale == 1.0) {
          expect(
            tester.getSize(course).height,
            tester
                .getSize(
                  find.byKey(const ValueKey('history-secondary-filters')),
                )
                .height,
          );
        }
        if (width >= 600) {
          await tester.tap(find.byKey(const ValueKey('history-date-filter')));
          await tester.pumpAndSettle();
          for (final (index, count) in [(0, 3), (1, 1), (2, 2)]) {
            expect(
              find.descendant(
                of: find.byKey(ValueKey('shell-select-option-$index')),
                matching: find.text('($count)'),
              ),
              findsOneWidget,
            );
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        await secondary(period: '7天内');
        expect(row('a_recent_未签到'), findsOneWidget);
        expect(row('a_old_已签到'), findsNothing);
        expect(row('b_older_已签到'), findsNothing);
        await secondary(period: '30天内');
        expect(row('a_old_已签到'), findsOneWidget);
        expect(row('b_older_已签到'), findsNothing);
        await secondary(period: '全部时间');
        expect(row('b_older_已签到'), findsOneWidget);
        await tester.tap(course);
        await tester.pumpAndSettle();
        final firstCourse = find.byKey(const ValueKey('shell-select-option-1'));
        expect(
          find.descendant(of: firstCourse, matching: find.text('(2)')),
          findsOneWidget,
        );
        await tester.tap(firstCourse);
        await tester.pumpAndSettle();
        expect(row('b_older_已签到'), findsNothing);
        await secondary(type: '二维码签到');
        expect(row('a_recent_未签到'), findsOneWidget);
        expect(row('a_old_已签到'), findsNothing);
        await tester.tap(
          find.descendant(of: status, matching: find.text('已签到')),
        );
        await tester.pumpAndSettle();
        expect(find.text('无匹配记录'), findsOneWidget);
        await tester.tap(
          find.descendant(of: status, matching: find.text('全部')),
        );
        await tester.pumpAndSettle();
        expect(row('a_recent_未签到'), findsOneWidget);
        if (width < 600) {
          await tester.tap(
            find.byKey(const ValueKey('history-secondary-filters')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(AppFilterChoice, '数字签到'));
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(
            row('a_recent_未签到'),
            findsOneWidget,
            reason: 'cancel leaves applied filters intact',
          );
          await tester.tap(
            find.byKey(const ValueKey('history-secondary-filters')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('重置'));
          await tester.pumpAndSettle();
          expect(
            row('a_old_已签到'),
            findsNothing,
            reason: 'reset stays local until applied',
          );
          await tester.tap(find.text('应用筛选'));
          await tester.pumpAndSettle();
        } else {
          await secondary(type: '全部类型');
        }
        expect(row('a_old_已签到'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
