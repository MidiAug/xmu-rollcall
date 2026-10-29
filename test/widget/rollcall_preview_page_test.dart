import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/rollcall/mobile_rollcall_home.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_preview_page.dart';
import '../fixtures/preview_fonts.dart';

Future<GlobalKey> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
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
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const RollcallPreviewPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
  await tester.tap(find.descendant(of: card, matching: find.text('去签到')));
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
  setUpAll(loadDesktopPreviewFonts);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'course_radar_defaults': '{"sentinel":{}}',
      'saved_radar_locations': '[]',
    }),
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
      expect(find.text('24.60497, 118.31378'), findsOneWidget);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/campus_header.png'),
          tester.element(find.byType(MobileRollcallHome)),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'ready');
      await tester.tap(find.text('开始检测'));
      await tester.pumpAndSettle();
      expect(find.text('停止'), findsOneWidget);
      await tester.tap(find.text('停止'));
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
        if (scenario == RollcallPreviewScenario.completed) {
          expect(find.text('签到完成'), findsNWidgets(3));
        }
        if (scenario == RollcallPreviewScenario.mixed) {
          expect(find.text('签到完成'), findsOneWidget);
        }
        if (scenario == RollcallPreviewScenario.ended) {
          expect(find.text('已结束'), findsWidgets);
        }
        if (scenario == RollcallPreviewScenario.missing) {
          expect(find.text('1234'), findsNothing);
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
      await _mount(tester);
      await _refresh(tester);
      await _tapTask(tester, 9001);
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.text('签到完成'), findsOneWidget);
      await _tapTask(tester, 9002);
      expect(find.byType(RollcallAnswerPage), findsNothing);
      expect(find.text('签到完成'), findsNWidgets(2));

      await _choose(tester, RollcallPreviewScenario.missing);
      await _tapTask(tester, 9001);
      expect(find.byType(RollcallAnswerPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(RollcallAnswerPage))).pop();
      await tester.pumpAndSettle();
      await _tapTask(tester, 9002);
      expect(find.byType(RollcallAnswerPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(RollcallAnswerPage))).pop();
      await tester.pumpAndSettle();

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
      expect(find.text('签到完成'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('course_radar_defaults'), '{"sentinel":{}}');
      expect(prefs.getInt('monitor_legacy_owner'), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
