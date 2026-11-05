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
                  const Expanded(child: SizedBox()),
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
    });

    testWidgets(
      'settings navigation has no hover wash and keeps keyboard activation dark=$dark',
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
        await tester.tap(find.text('地点管理'));
        await tester.pumpAndSettle();
        await mouse.moveTo(const Offset(600, 500));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 2);
      },
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
      theme.overlayColor!.resolve({WidgetState.pressed})!.a,
      greaterThan(0),
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
