import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/features/rollcall/mobile_rollcall_home.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_preview_page.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';
import 'package:flutter_map/flutter_map.dart';
import '../fixtures/preview_fonts.dart';

Future<GlobalKey> _mount(
  WidgetTester tester, {
  bool dark = false,
  bool desktop = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final capture = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      child: RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: desktop ? TargetPlatform.windows : TargetPlatform.android,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RollcallPreviewPage(desktop: desktop),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (desktop) {
    await tester.runAsync(
      () => precacheImage(
        const ResizeImage(
          AssetImage('assets/illustrations/campus_mist.png'),
          width: 768,
        ),
        tester.element(find.byType(RollcallPreviewPage)),
      ),
    );
    await tester.pumpAndSettle();
  }
  return capture;
}

Future<void> _refresh(WidgetTester tester, {bool loading = false}) async {
  await tester
      .widget<AppPullToRefresh>(find.byType(AppPullToRefresh))
      .onRefresh();
  if (loading) {
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> _choose(
  WidgetTester tester,
  RollcallPreviewScenario scenario,
) async {
  tester
      .widget<AppShellSelect<RollcallPreviewScenario>>(
        find.byKey(const ValueKey('rollcall-preview-scenario')),
      )
      .onChanged!(scenario);
  await tester.pumpAndSettle();
  await _refresh(tester, loading: scenario == RollcallPreviewScenario.loading);
}

Future<void> _tapTask(WidgetTester tester, int id) async {
  final card = find.byKey(ValueKey('mobile-rollcall-$id'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: card, matching: find.byType(FilledButton)),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['CAPTURE_ROLLCALL_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/rollcall-home-preview').create(recursive: true);
    await File(
      'build/rollcall-home-preview/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final icons = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/rollcall-home-preview-map-cache',
          ).create(recursive: true)).absolute.path,
        );
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'course_radar_defaults': '{"sentinel":{}}',
      'saved_radar_locations': '[]',
    }),
  );

  testWidgets('desktop preview uses real task cards and completed scenarios', (
    tester,
  ) async {
    final capture = await _mount(tester, desktop: true, width: 1104);
    expect(find.byType(MobileRollcallHome), findsNothing);
    expect(find.byType(AppMobileNav), findsNothing);
    expect(find.byType(RollcallTaskCard), findsNWidgets(3));
    expect(find.text('数字签到'), findsNothing);
    expect(find.text('雷达签到'), findsNothing);
    expect(find.text('预览老师'), findsNWidgets(3));
    expect(find.byIcon(AppIcons.number), findsWidgets);
    expect(find.byIcon(AppIcons.location), findsWidgets);
    expect(find.byIcon(AppIcons.qr), findsWidgets);
    await _capture(tester, capture, 'desktop-ready');
    final initialCard = tester.getRect(find.byType(RollcallTaskCard).first);
    await tester.tap(find.widgetWithText(FilledButton, '签到').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '已签到'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(
      tester.getSize(find.byType(RollcallTaskCard).first),
      initialCard.size,
    );
    final completedCard = find.byType(RollcallTaskCard).first;
    expect(
      find.descendant(
        of: completedCard,
        matching: find.byType(AttendanceCountRow),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AttendanceCountRow>(
            find.descendant(
              of: completedCard,
              matching: find.byType(AttendanceCountRow),
            ),
          )
          .completed,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FilledButton, '签到'));
    await tester.pumpAndSettle();
    expect(find.byType(RollcallAnswerPage), findsNothing);
    expect(find.text('已签到'), findsNWidgets(2));
    AppToast.dismiss();
    await tester.pump(const Duration(seconds: 3));
    tester
        .widget<AppShellSelect<RollcallPreviewScenario>>(
          find.byKey(const ValueKey('rollcall-preview-scenario')),
        )
        .onChanged!(RollcallPreviewScenario.completed);
    await tester.pumpAndSettle();
    expect(find.byType(RollcallTaskCard), findsNWidgets(3));
    expect(find.widgetWithText(FilledButton, '已签到'), findsNWidgets(3));
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('二维码'), findsOneWidget);
    await _capture(tester, capture, 'desktop-completed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop missing number uses the shared manual entry dialog', (
    tester,
  ) async {
    await _mount(tester, desktop: true, width: 1104);
    await _choose(tester, RollcallPreviewScenario.missing);
    await tester.tap(find.widgetWithText(FilledButton, '手动输入'));
    await tester.pumpAndSettle();
    expect(find.text('输入签到码'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5678');
    await tester.tap(find.widgetWithText(FilledButton, '签到').last);
    await tester.pumpAndSettle();
    expect(find.text('已签到'), findsWidgets);
    AppToast.dismiss();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('desktop pending cards adapt to narrow width and large text', (
    tester,
  ) async {
    for (final entry in [(640.0, 1.5, false), (1104.0, 1.0, true)]) {
      final capture = await _mount(
        tester,
        desktop: true,
        width: entry.$1,
        scale: entry.$2,
        dark: entry.$3,
      );
      await _choose(tester, RollcallPreviewScenario.number);
      expect(find.widgetWithText(FilledButton, '签到'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        capture,
        entry.$3 ? 'desktop-dark' : 'desktop-large-text',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'method hint typography and icon centers match on Android and desktop',
    (tester) async {
      for (final desktop in [false, true]) {
        final capture = await _mount(
          tester,
          desktop: desktop,
          width: desktop ? 1104 : 390,
        );
        await _choose(tester, RollcallPreviewScenario.missing);
        final styles = <TextStyle>[];
        for (final label in ['无法获取签到码', '需补充签到位置', '二维码']) {
          final text = find.text(label);
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          styles.add(tester.widget<Text>(text).style!);
          final row = find.ancestor(of: text, matching: find.byType(Row)).first;
          final icon = find
              .descendant(of: row, matching: find.byType(Icon))
              .first;
          expect(
            tester.getCenter(icon).dy,
            closeTo(tester.getCenter(text).dy, .5),
          );
        }
        expect(styles.toSet(), hasLength(1));
        expect(styles.first.fontSize, 18);
        expect(styles.first.fontWeight, FontWeight.w400);
        await _capture(
          tester,
          capture,
          desktop ? 'desktop-hints' : 'android-hints',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'full real home renders every method and state combination after refresh',
    (tester) async {
      final capture = await _mount(tester);
      expect(find.byType(MobileRollcallHome), findsOneWidget);
      expect(find.byType(AppMobileNav), findsOneWidget);
      expect(find.text('签到'), findsWidgets);
      expect(find.byType(RollcallTaskCard), findsNothing);
      await _refresh(tester);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('学武楼 A区'), findsOneWidget);
      expect(find.text('24.60497, 118.31378'), findsNothing);
      expect(find.text('签到码'), findsNothing);
      final numeric = find.byKey(const ValueKey('mobile-rollcall-9001'));
      Finder inside(Finder finder) =>
          find.descendant(of: numeric, matching: finder);
      expect(
        tester.widget<Icon>(inside(find.byIcon(AppIcons.number))).size,
        tester.widget<Text>(inside(find.text('1234'))).style!.fontSize,
      );
      for (final input in [
        (9002, AppIcons.location, '学武楼 A区'),
        (9003, AppIcons.qr, '二维码'),
      ]) {
        final card = find.byKey(ValueKey('mobile-rollcall-${input.$1}'));
        final icon = tester.widget<Icon>(
          find.descendant(of: card, matching: find.byIcon(input.$2)),
        );
        final text = tester.widget<Text>(
          find.descendant(of: card, matching: find.text(input.$3)),
        );
        expect(icon.size, text.style!.fontSize);
      }
      final titleRect = tester.getRect(inside(find.text('专业英语')));
      final teacherRect = tester.getRect(inside(find.text('预览老师')));
      final countRect = tester.getRect(inside(find.byType(AttendanceCountRow)));
      final timeRect = tester.getRect(inside(find.textContaining('更新于')));
      final codeRect = tester.getRect(inside(find.text('1234')));
      final buttonRect = tester.getRect(
        inside(find.widgetWithText(FilledButton, '签到')),
      );
      final buttonSize = tester.getSize(inside(find.byType(FilledButton)));
      expect(titleRect.left, lessThan(countRect.left));
      expect(teacherRect.top, greaterThan(titleRect.bottom));
      expect(timeRect.top, greaterThanOrEqualTo(countRect.bottom));
      expect(codeRect.left, lessThan(buttonRect.left));
      expect(codeRect.top, greaterThan(teacherRect.bottom));
      expect(buttonRect.top, greaterThan(timeRect.bottom));
      expect(find.text('待签到'), findsNothing);
      expect(find.text('数字签到'), findsNothing);
      expect(find.byTooltip('课程操作'), findsNothing);
      String? copiedCode;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedCode = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(inside(find.text('1234')));
      await tester.pumpAndSettle();
      expect(copiedCode, '1234');
      AppToast.dismiss();
      await tester.pumpAndSettle();
      copiedCode = null;
      Focus.of(tester.element(inside(find.text('1234')))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copiedCode, '1234');
      AppToast.dismiss();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/campus_header.png'),
          tester.element(find.byType(MobileRollcallHome)),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'ready');
      final startRect = tester.getRect(
        find.widgetWithText(OutlinedButton, '开始检测'),
      );
      expect(
        tester.getRect(find.byIcon(AppIcons.settings)).right,
        closeTo(startRect.right, .1),
      );
      final idleStatusRect = tester.getRect(
        find.byKey(const ValueKey('android-detection-status')),
      );
      await tester.tap(find.text('开始检测'));
      await tester.pumpAndSettle();
      expect(find.text('停止检测'), findsOneWidget);
      expect(find.byIcon(AppIcons.stopSolid), findsOneWidget);
      final stopRect = tester.getRect(
        find.widgetWithText(OutlinedButton, '停止检测'),
      );
      final runningStatusRect = tester.getRect(
        find.byKey(const ValueKey('android-detection-status')),
      );
      expect(stopRect.top, closeTo(startRect.top, .1));
      expect(stopRect.left, closeTo(startRect.left, .1));
      expect(runningStatusRect.top, closeTo(idleStatusRect.top, .1));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('android-detection-status')),
            )
            .data,
        matches(RegExp(r'^检测中 \d+ s$')),
      );
      await _capture(tester, capture, 'started');
      await tester.tap(find.text('停止检测'));
      await tester.pumpAndSettle();
      expect(find.text('开始检测'), findsOneWidget);

      for (final scenario in RollcallPreviewScenario.values) {
        await _choose(tester, scenario);
        expect(tester.takeException(), isNull, reason: scenario.label);
        final count = switch (scenario) {
          RollcallPreviewScenario.empty ||
          RollcallPreviewScenario.failure ||
          RollcallPreviewScenario.loading => 0,
          RollcallPreviewScenario.number ||
          RollcallPreviewScenario.radar ||
          RollcallPreviewScenario.qr => 1,
          _ => 3,
        };
        expect(
          find.byType(RollcallTaskCard),
          findsNWidgets(count),
          reason: scenario.label,
        );
        for (final card in tester.widgetList<RollcallTaskCard>(
          find.byType(RollcallTaskCard),
        )) {
          final action = find.descendant(
            of: find.byWidget(card),
            matching: find.byType(FilledButton),
          );
          expect(tester.getSize(action), buttonSize, reason: scenario.label);
        }
        if (scenario == RollcallPreviewScenario.completed) {
          expect(find.widgetWithText(FilledButton, '已签到'), findsNWidgets(3));
        }
        if (scenario == RollcallPreviewScenario.mixed) {
          expect(find.widgetWithText(FilledButton, '已签到'), findsOneWidget);
        }
        if (scenario == RollcallPreviewScenario.ended) {
          expect(find.text('已结束'), findsWidgets);
        }
        if (scenario == RollcallPreviewScenario.missing) {
          expect(find.text('1234'), findsNothing);
          expect(find.text('无法获取签到码'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, '手动输入'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, '选择位置'), findsOneWidget);
          expect(find.text('需补充签到位置'), findsOneWidget);
        }
        if (scenario == RollcallPreviewScenario.empty) {
          expect(find.text('暂无正在签到的课程'), findsOneWidget);
        }
        if (scenario == RollcallPreviewScenario.failure) {
          expect(find.text('暂时无法确认签到状态'), findsOneWidget);
        }
        if (scenario == RollcallPreviewScenario.loading) {
          expect(find.text('正在确认最新状态…'), findsOneWidget);
        }
        if (scenario != RollcallPreviewScenario.loading) {
          await _capture(tester, capture, scenario.name);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'full home uses real direct submission and missing-input navigation',
    (tester) async {
      final capture = await _mount(tester);
      await _refresh(tester);
      final previewContainer = ProviderScope.containerOf(
        tester.element(find.byType(MobileRollcallHome)),
      );
      await _tapTask(tester, 9001);
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.widgetWithText(FilledButton, '已签到'), findsOneWidget);
      AppToast.dismiss();
      await _tapTask(tester, 9002);
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.widgetWithText(FilledButton, '已签到'), findsNWidgets(2));

      await _choose(tester, RollcallPreviewScenario.missing);
      AppToast.dismiss();
      await _tapTask(tester, 9001);
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.text('输入签到码'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '5678');
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'number-dialog');
      await tester.tap(find.widgetWithText(FilledButton, '签到').last);
      await tester.pumpAndSettle();
      expect(find.text('5678'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '已签到'), findsOneWidget);
      AppToast.dismiss();
      await _tapTask(tester, 9002);
      expect(find.byType(RollcallAnswerPage), findsOneWidget);
      expect(find.byType(MapPickPanel), findsOneWidget);
      final mapAction = find.widgetWithText(FilledButton, '签到');
      expect(tester.widget<FilledButton>(mapAction).onPressed, isNull);
      expect(
        tester
            .widget<RollcallAnswerPage>(find.byType(RollcallAnswerPage))
            .mapDialog,
        isTrue,
      );
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(RollcallAnswerPage)),
        ),
        same(previewContainer),
      );
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(
        find.widgetWithText(FilledButton, '已签到'),
        findsOneWidget,
        reason: 'Canceling location selection does not submit the radar task',
      );
      await _tapTask(tester, 9002);
      expect(tester.widget<FilledButton>(mapAction).onPressed, isNull);
      await tester.tap(find.byType(FlutterMap).first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(mapAction).onPressed, isNotNull);
      await _capture(tester, capture, 'radar-picker');
      await tester.tap(mapAction);
      await tester.pumpAndSettle();
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.widgetWithText(FilledButton, '已签到'), findsNWidgets(2));

      await _choose(tester, RollcallPreviewScenario.qr);
      await _tapTask(tester, 9003);
      expect(find.byType(QrAnswerPage), findsOneWidget);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': 'preview-qr'} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('粘贴内容并提交'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(QrAnswerPage))).pop();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '已签到'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('course_radar_defaults'), '{"sentinel":{}}');
      expect(prefs.getInt('monitor_legacy_owner'), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'four-corner cards keep long titles and large text usable in both themes',
    (tester) async {
      for (final dark in [false, true]) {
        final capture = await _mount(
          tester,
          dark: dark,
          width: 320,
          scale: 1.3,
        );
        await _refresh(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MobileRollcallHome)),
        );
        final original = container
            .read(activeRollcallsProvider(null))
            .requireValue
            .first;
        container
            .read(activeRollcallsProvider(null).notifier)
            .patchItem(
              RollcallItem(
                rollcallId: original.rollcallId,
                courseTitle: '非常长的专业英语课程名称以及研究生实践与应用课程',
                createdByName: '很长的任课教师姓名与课程助教',
                type: original.type,
                status: original.status,
                rollcallStatus: original.rollcallStatus,
                isExpired: false,
                scored: false,
                numberCode: original.numberCode,
              ),
            );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final action = find.descendant(
          of: find.byKey(const ValueKey('mobile-rollcall-9001')),
          matching: find.widgetWithText(FilledButton, '签到'),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        await tester.ensureVisible(
          find.byKey(const ValueKey('mobile-rollcall-9001')),
        );
        await tester.pumpAndSettle();
        await _capture(
          tester,
          capture,
          dark ? 'card-narrow-dark' : 'card-narrow-light',
        );
        await _choose(tester, RollcallPreviewScenario.missing);
        await _tapTask(tester, 9002);
        expect(find.byType(MapPickPanel), findsOneWidget);
        await _capture(
          tester,
          capture,
          dark ? 'radar-picker-narrow-dark' : 'radar-picker-narrow-light',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
