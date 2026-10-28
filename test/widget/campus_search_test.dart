import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../fixtures/preview_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_search_page.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_SEARCH_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  testWidgets('four tabs, independent search, badge and help/back route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        campusCachedDataProvider.overrideWith(
          (ref) async => const CampusCachedData(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (_, child) =>
              RepaintBoundary(key: captureKey, child: child!),
          theme: AppTheme.light().copyWith(
            platform: TargetPlatform.android,
            textTheme: AppTheme.light().textTheme.apply(
              fontFamily: 'Microsoft YaHei UI',
            ),
            listTileTheme: AppTheme.light().listTileTheme.copyWith(
              titleTextStyle: AppTheme.light().listTileTheme.titleTextStyle
                  ?.copyWith(fontFamily: 'Microsoft YaHei UI'),
              subtitleTextStyle: AppTheme.light()
                  .listTileTheme
                  .subtitleTextStyle
                  ?.copyWith(fontFamily: 'Microsoft YaHei UI'),
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: const Text('首页'),
              bottomNavigationBar: AppMobileNav(
                current: AppDestination.rollcall,
                onSelect: (_) {},
                homeworkCount: 12,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CampusSearchPage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    for (final label in ['签到', '作业', '工具', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('global-search-button')));
    await tester.pumpAndSettle();
    if (Platform.environment['CAPTURE_SEARCH_UI'] == '1') {
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/android-masthead-polish/search.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await tester.enterText(
      find.byKey(const ValueKey('campus-search-field')),
      '自动签到怎么用',
    );
    await tester.pumpAndSettle();
    expect(find.text('自动检测设置'), findsOneWidget);
    await tester.tap(find.text('自动检测设置'));
    await tester.pumpAndSettle();
    expect(find.text('打开功能'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    container.read(selectedRollcallAccountProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('campus-search-field')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(
      find.byKey(const ValueKey('campus-search-field')),
      '找不到的词xyz',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有找到结果，试试功能名称或关键词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
