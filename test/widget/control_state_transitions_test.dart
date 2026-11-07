import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

Future<List<int>> _pixels(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List().toList();
  }))!;
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });

  for (final dark in [false, true]) {
    for (final scenario in [
      for (final kind in AppButtonKind.values)
        for (final icon in [null, AppIcons.upload]) (kind, icon),
    ]) {
      final (kind, icon) = scenario;
      testWidgets(
        'busy action preserves its neighbours dark=$dark kind=$kind icon=$icon',
        (tester) async {
          var busy = false;
          var calls = 0;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: desktopCaptureTheme(
                (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: TargetPlatform.windows,
                ),
              ),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, set) {
                      update = set;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: '导入成绩',
                            kind: kind,
                            icon: icon,
                            busy: busy,
                            onPressed: () => calls++,
                          ),
                          const SizedBox(width: 12),
                          TextButton(onPressed: () {}, child: const Text('取消')),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = tester.getRect(find.byType(AppButton));
          final neighbour = tester.getRect(find.text('取消'));
          update(() => busy = true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await captureDesktopUi(
            tester,
            'state-audit-busy-$dark-${kind.name}-${icon != null}',
          );
          await tester.tap(find.byType(AppButton));
          expect(calls, 0);
          expect(tester.getRect(find.byType(AppButton)), button);
          expect(tester.getRect(find.text('取消')), neighbour);
          update(() => busy = false);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(AppButton));
          expect(calls, 1);
        },
      );
    }
    for (final selected in [false, true]) {
      testWidgets(
        'menu press and cancel preserve selection dark=$dark selected=$selected',
        (tester) async {
          final boundary = GlobalKey();
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: desktopCaptureTheme(
                (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: TargetPlatform.windows,
                ),
              ),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: RepaintBoundary(
                      key: boundary,
                      child: AppMenuOption(
                        label: '当前课程',
                        selected: selected,
                        showCheck: true,
                        onTap: () => calls++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final geometry = tester.getRect(find.byType(AppMenuOption));
          final idle = await _pixels(tester, boundary);
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(geometry.center);
          await tester.pumpAndSettle();
          final hovered = await _pixels(tester, boundary);
          await captureDesktopUi(
            tester,
            'state-audit-menu-hover-$dark-$selected',
          );
          await mouse.down(geometry.center);
          await tester.pumpAndSettle();
          final pressed = await _pixels(tester, boundary);
          await captureDesktopUi(
            tester,
            'state-audit-menu-press-$dark-$selected',
          );
          await mouse.cancel();
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(await _pixels(tester, boundary), idle);
          expect(calls, 0);
          expect(tester.getRect(find.byType(AppMenuOption)), geometry);
          final semantics = tester.getSemantics(find.text('当前课程'));
          expect(
            semantics.flagsCollection.isSelected,
            selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
          );
          expect(
            pressed,
            isNot(hovered),
            reason: 'holding an option needs feedback beyond pointer hover',
          );
        },
      );
    }
    testWidgets(
      'reduced motion menu highlights settle without animation dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: AppMenuOption(
                    label: '当前课程',
                    selected: false,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byType(AppMenuOption)));
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
    for (final kind in ['shared-icon', 'theme-icon', 'text', 'outlined']) {
      testWidgets('disabled $kind ignores hover and activation dark=$dark', (
        tester,
      ) async {
        final boundary = GlobalKey();
        var calls = 0;
        final enabledFocus = FocusNode();
        addTearDown(enabledFocus.dispose);
        final control = switch (kind) {
          'shared-icon' => const AppIconButton(
            tooltip: '下载附件',
            framed: true,
            icon: Icon(AppIcons.download),
            onPressed: null,
          ),
          'theme-icon' => const IconButton(
            onPressed: null,
            icon: Icon(AppIcons.download),
          ),
          'text' => const TextButton(onPressed: null, child: Text('导入成绩')),
          _ => const OutlinedButton(onPressed: null, child: Text('下载打包')),
        };
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: desktopCaptureTheme(
              (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('暂不可用的操作：$kind'),
                    const SizedBox(height: 16),
                    RepaintBoundary(key: boundary, child: control),
                    const SizedBox(height: 16),
                    TextButton(
                      focusNode: enabledFocus,
                      onPressed: () => calls++,
                      child: const Text('下一项'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = await _pixels(tester, boundary);
        final geometry = tester.getRect(find.byKey(boundary));
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(geometry.center);
        await tester.pumpAndSettle();
        await captureDesktopUi(tester, 'state-audit-disabled-$kind-$dark');
        expect(
          await _pixels(tester, boundary),
          before,
          reason: 'disabled actions must not gain an enabled hover surface',
        );
        await tester.tapAt(geometry.center);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(enabledFocus.hasFocus, isTrue);
        expect(calls, 0);
        expect(tester.getRect(find.byKey(boundary)), geometry);
      });
    }
  }
}
