import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopUiCaptureFonts();
    await loadDesktopPreviewFonts();
  });
  for (final dark in [false, true]) {
    testWidgets('actions highlight without hover outlines dark=$dark', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: desktopCaptureTheme(dark ? AppTheme.dark() : AppTheme.light()),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: ColoredBox(
                color: (dark ? AppTheme.dark() : AppTheme.light())
                    .scaffoldBackgroundColor,
                child: SizedBox(
                  width: 400,
                  height: 500,
                  child: Column(
                    children: [
                      TextButton(
                        focusNode: focus,
                        onPressed: () {},
                        child: const Text('退出'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('次操作'),
                      ),
                      AppIconButton(
                        tooltip: '刷新',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {},
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                      AppSelectTrigger(label: '选择学期', onTap: () {}),
                      AppHoverSurface(
                        onTap: () {},
                        child: const SizedBox(
                          width: 160,
                          height: 44,
                          child: Text('查看课程'),
                        ),
                      ),
                      AppRefreshButton(tooltip: '刷新作业', onRefresh: () async {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 550));
      addTearDown(mouse.removePointer);
      // Read painted Material/BoxDecoration state after actual pointer events.
      for (final (index, target) in [
        find.byType(TextButton),
        find.byType(OutlinedButton),
        find.byType(AppIconButton).first,
        find.widgetWithIcon(IconButton, Icons.add),
        find.byType(AppSelectTrigger),
        find.byType(AppHoverSurface),
        find.byType(AppRefreshButton),
      ].indexed) {
        final materials = find.descendant(
          of: target,
          matching: find.byType(Material),
        );
        final containers = find.descendant(
          of: target,
          matching: find.byType(AnimatedContainer),
        );
        Object? border() => materials.evaluate().isNotEmpty
            ? (tester.widget<Material>(materials.first).shape as OutlinedBorder)
                  .side
            : (tester.widget<AnimatedContainer>(containers.first).decoration
                      as BoxDecoration)
                  .border;
        Color? fill() => materials.evaluate().isNotEmpty
            ? tester.widget<Material>(materials.first).color
            : (tester.widget<AnimatedContainer>(containers.first).decoration
                      as BoxDecoration)
                  .color;
        final idleBorder = border();
        if (index == 6) expect((idleBorder as BorderSide).color.a, 0);
        final idleFill = fill();
        final size = tester.getSize(target);
        await mouse.moveTo(tester.getCenter(target));
        await tester.pumpAndSettle();
        expect(border(), idleBorder);
        expect(fill(), isNot(idleFill));
        expect(tester.getSize(target), size);
        await captureDesktopUi(tester, 'button-hover-$dark-$index');
        await mouse.moveTo(const Offset(700, 550));
        await tester.pumpAndSettle();
        expect(border(), idleBorder);
        expect(fill(), idleFill);
      }
      focus.requestFocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focusedMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(OutlinedButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (focusedMaterial.shape as OutlinedBorder).side.color,
        (dark ? AppTheme.dark() : AppTheme.light()).colorScheme.primary,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
