import 'package:xmu_rollcall/app/desktop/desktop_page.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

Future<Color> pixel(
  WidgetTester tester,
  GlobalKey capture,
  Offset point,
) async {
  final result = await tester.runAsync(() async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final color = Color.fromARGB(
      bytes[at + 3],
      bytes[at],
      bytes[at + 1],
      bytes[at + 2],
    );
    image.dispose();
    return color;
  });
  return result!;
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'D:/Dev/Flutter-xmu';
    final font = File(
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (font.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final dark in [false, true]) {
    testWidgets('narrow window chrome states render together dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.windows,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Column(
                children: [
                  const AppTitleBar(title: '厦大签到'),
                  Expanded(
                    child: Row(
                      children: [
                        AppSidebar(
                          current: AppDestination.settings,
                          onSelect: (_) {},
                          accountControl: RollcallAccountMenu(
                            sidebar: true,
                            width: 124,
                            value: 0,
                            ownerName: '名字比较长的同学',
                            identities: const [],
                            watchingAccounts: const {0},
                            onChanged: (_) {},
                          ),
                        ),
                        Expanded(
                          child: PageScaffold(
                            title: '交互状态预览',
                            onBack: () {},
                            trailing: AppSheetCloseButton(onPressed: () {}),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: SettingsSection(
                                header: '常用',
                                children: [
                                  SettingsRow(
                                    title: '地点管理',
                                    subtitle: '查看与设置上课地点',
                                    leading: const Icon(AppIcons.location),
                                    trailing: const Icon(AppIcons.right),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/campus_sidebar.png'),
          tester.element(find.byType(AppSidebar)),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(850, 550));
      addTearDown(mouse.removePointer);
      for (final target in ['设置', '地点管理', '返回', '关闭']) {
        final finder = target == '设置'
            ? find.descendant(
                of: find.byType(AppSidebar),
                matching: find.text('设置'),
              )
            : target == '地点管理'
            ? find.text(target)
            : find.byTooltip(target);
        await mouse.moveTo(tester.getCenter(finder));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_CHROME_STATES'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/chrome-state-review').createSync(recursive: true);
            File(
              'build/chrome-state-review/$target-$dark.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
  for (final dark in [false, true]) {
    testWidgets('sidebar selection survives pointer hover dark=$dark', (
      tester,
    ) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: Row(
                children: [
                  AppSidebar(
                    current: AppDestination.campusTools,
                    onSelect: (_) {},
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: dark
                          ? AppPalette.darkPalette.canvas
                          : AppPalette.lightPalette.canvas,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selected = find.ancestor(
        of: find.text('工具'),
        matching: find.byType(TextButton),
      );
      final rect = tester.getRect(selected);
      final sample = Offset(rect.right - 20, rect.center.dy);
      final idle = await pixel(tester, capture, sample);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(600, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(rect.center);
      await tester.pumpAndSettle();
      expect(await pixel(tester, capture, sample), idle);
      final other = find.widgetWithText(TextButton, '作业');
      final otherRect = tester.getRect(other);
      final otherSample = Offset(otherRect.right - 20, otherRect.center.dy);
      await mouse.moveTo(const Offset(600, 500));
      await tester.pumpAndSettle();
      final before = await pixel(tester, capture, otherSample);
      await mouse.moveTo(otherRect.center);
      await tester.pumpAndSettle();
      final after = await pixel(tester, capture, otherSample);
      expect(
        (after.computeLuminance() - before.computeLuminance()).abs(),
        greaterThan(dark ? .01 : .035),
      );
      expect(after, isNot(idle));
      await _captureState(tester, capture, 'sidebar-hover-$dark');
      await mouse.moveTo(const Offset(600, 500));
      await tester.pumpAndSettle();
      expect(await pixel(tester, capture, otherSample), before);
    });

    testWidgets(
      'account switch clears transient fill and retains current check dark=$dark',
      (tester) async {
        final capture = GlobalKey();
        var value = 0;
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            builder: (context, child) =>
                RepaintBoundary(key: capture, child: child!),
            home: Scaffold(
              body: ColoredBox(
                color: p.sidebar,
                child: SizedBox(
                  width: 176,
                  child: StatefulBuilder(
                    builder: (context, set) => RollcallAccountMenu(
                      sidebar: true,
                      width: 156,
                      value: value,
                      ownerName: '主账号同学',
                      identities: const [
                        AssistIdentity(
                          userId: 2,
                          displayName: '协助同学',
                          kind: AssistCredentialKind.session,
                          deviceId: 'test-device',
                        ),
                      ],
                      onChanged: (next) => set(() => value = next),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final trigger = find.descendant(
          of: find.byType(RollcallAccountMenu),
          matching: find.byType(TextButton),
        );
        final rect = tester.getRect(trigger);
        final point = Offset(rect.right - 25, rect.top + 4);
        final idle = await pixel(tester, capture, point);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(600, 500));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(trigger));
        await mouse.down(tester.getCenter(trigger));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(await pixel(tester, capture, point), isNot(idle));
        await _captureState(tester, capture, 'account-open-$dark');
        await mouse.moveTo(
          tester.getCenter(find.widgetWithText(AppMenuOption, '协助同学')),
        );
        await mouse.down(
          tester.getCenter(find.widgetWithText(AppMenuOption, '协助同学')),
        );
        await mouse.up();
        await mouse.moveTo(const Offset(600, 500));
        await tester.pumpAndSettle();
        expect(value, 2);
        expect(tester.widget<TextButton>(trigger).focusNode!.hasFocus, isFalse);
        expect(find.byType(AppMenuOption), findsNothing);
        expect(await pixel(tester, capture, point), idle);
        expect(
          await pixel(
            tester,
            capture,
            rect.topLeft + Offset(1, rect.height / 2),
          ),
          p.sidebar,
        );
        await _captureState(tester, capture, 'account-switched-$dark');
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppMenuOption>(find.widgetWithText(AppMenuOption, '协助同学'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<AppMenuOption>(find.widgetWithText(AppMenuOption, '协助同学'))
              .showCheck,
          isTrue,
        );
        await _captureState(tester, capture, 'account-current-$dark');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNothing);
        expect(tester.widget<TextButton>(trigger).focusNode!.hasFocus, isTrue);
        expect(await pixel(tester, capture, point), idle);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'settings navigation has no hover or press wash and keeps keyboard activation dark=$dark',
      (tester) async {
        var calls = 0;
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: capture,
                child: ColoredBox(
                  color: dark
                      ? AppPalette.darkPalette.surface
                      : AppPalette.lightPalette.surface,
                  child: SizedBox(
                    width: 420,
                    child: SettingsRow(
                      title: '地点管理',
                      leading: const Icon(AppIcons.location),
                      trailing: const Icon(AppIcons.right),
                      onTap: () => calls++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final idle = await pixel(tester, capture, const Offset(330, 28));
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(600, 500));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(const Offset(220, 28));
        await tester.pumpAndSettle();
        expect(await pixel(tester, capture, const Offset(330, 28)), idle);
        await mouse.down(const Offset(220, 28));
        for (final elapsed in [20, 100, 250]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(await pixel(tester, capture, const Offset(330, 28)), idle);
        }
        await _captureState(tester, capture, 'settings-held-$dark');
        await mouse.cancel();
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(await pixel(tester, capture, const Offset(330, 28)), idle);
        final touch = await tester.startGesture(const Offset(220, 28));
        await tester.pump(const Duration(milliseconds: 250));
        expect(await pixel(tester, capture, const Offset(330, 28)), idle);
        await touch.cancel();
        await tester.pumpAndSettle();
        expect(calls, 0);
        await tester.tap(find.text('地点管理'));
        await tester.pumpAndSettle();
        await mouse.moveTo(const Offset(600, 500));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(
          await pixel(tester, capture, const Offset(0, 28)),
          dark ? AppPalette.darkPalette.focus : AppPalette.lightPalette.focus,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(calls, 3);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  for (final owner in [true, false]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'watch status does not wrap the narrow sidebar role owner=$owner scale=$scale',
        (tester) async {
          Future<void> show(Set<int> watching) => tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.windows,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 124,
                    child: RollcallAccountMenu(
                      sidebar: true,
                      width: 124,
                      value: owner ? 0 : 2,
                      identities: const [
                        AssistIdentity(
                          userId: 2,
                          displayName: '名字比较长的协助同学',
                          kind: AssistCredentialKind.session,
                          deviceId: 'test-device',
                        ),
                      ],
                      ownerName: '名字比较长的同学',
                      watchingAccounts: watching,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await show({});
          await tester.pumpAndSettle();
          final role = owner ? '主账号' : '协助账号';
          final height = tester.getSize(find.text(role)).height;
          await show({owner ? 0 : 2});
          await tester.pumpAndSettle();
          expect(tester.getSize(find.text(role)).height, height);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final (dark, closing) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    testWidgets(
      '${closing ? 'sheet close' : 'page back'} keeps hover and press borderless dark=$dark',
      (tester) async {
        final capture = GlobalKey();
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: capture,
                child: ColoredBox(
                  color: dark
                      ? AppPalette.darkPalette.canvas
                      : AppPalette.lightPalette.canvas,
                  child: Column(
                    children: [
                      DesktopPageHeader(
                        title: '签到设置',
                        onBack: closing ? null : () => calls++,
                        actions: [
                          if (closing)
                            AppSheetCloseButton(onPressed: () => calls++),
                        ],
                      ),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final back = find.byTooltip(closing ? '关闭' : '返回');
        final rect = tester.getRect(back);
        final size = tester.getSize(back);
        final edge = Offset(rect.left, rect.center.dy);
        final inside = edge + const Offset(3, 0);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(790, 590));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(rect.center);
        await tester.pumpAndSettle();
        expect(
          await pixel(tester, capture, edge),
          await pixel(tester, capture, inside),
        );
        await _captureState(
          tester,
          capture,
          '${closing ? 'close' : 'back'}-hover-$dark',
        );
        await mouse.down(rect.center);
        await tester.pumpAndSettle();
        expect(
          await pixel(tester, capture, edge),
          await pixel(tester, capture, inside),
        );
        await _captureState(
          tester,
          capture,
          '${closing ? 'close' : 'back'}-held-$dark',
        );
        await mouse.up();
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.getSize(back), size);
        expect(
          await pixel(tester, capture, edge),
          await pixel(tester, capture, inside),
        );
        await mouse.moveTo(const Offset(790, 590));
        await tester.pumpAndSettle();
        expect(
          await pixel(tester, capture, edge),
          await pixel(tester, capture, inside),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        expect(await pixel(tester, capture, edge), p.focus);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 2);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('legacy icon actions inherit the rounded rectangle surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: IconButton(
            tooltip: '返回',
            onPressed: () {},
            icon: const Icon(AppIcons.back),
          ),
        ),
      ),
    );
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(IconButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.shape, isA<RoundedRectangleBorder>());
    final theme = Theme.of(
      tester.element(find.byType(IconButton)),
    ).iconButtonTheme.style!;
    expect(
      theme.backgroundColor!.resolve({WidgetState.pressed}),
      AppPalette.of(tester.element(find.byType(IconButton))).controlPressed,
    );
  });
  for (final dark in [false, true]) {
    testWidgets('search hover preserves its surface and bounds dark=$dark', (
      tester,
    ) async {
      final key = GlobalKey();
      final theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
        platform: TargetPlatform.windows,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 230,
                    child: AppSearchField(hintText: '搜索姓名或学号'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final rect = tester.getRect(field);
      final point = rect.topLeft + Offset(rect.width - 30, 12);
      final before = await pixel(tester, key, point);
      final p = AppPalette.of(tester.element(field));
      expect(before, p.surface);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(rect.center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(await pixel(tester, key, point), before);
      expect(tester.getRect(field), rect);
      expect(before, isNot(p.canvas));
      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 200));
      final decoration = tester
          .widget<InputDecorator>(
            find.descendant(of: field, matching: find.byType(InputDecorator)),
          )
          .decoration;
      expect(decoration.focusedBorder!.borderSide.color, p.primary);
      expect(p.focus, p.primary);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _captureState(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (Platform.environment['CAPTURE_CHROME_STATES'] != '1') return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      'build/chrome-state-review',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
