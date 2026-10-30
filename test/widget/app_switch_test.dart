import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  testWidgets('reduced motion follows the system preference', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AppSwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    final thumb = find.byKey(const ValueKey('app-switch-thumb'));
    final start = tester.getCenter(thumb).dx;
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(tester.getCenter(thumb).dx, greaterThan(start));
    expect(tester.hasRunningAnimations, isFalse);
  });
  for (final rtl in [false, true]) {
    testWidgets('thumb travels visibly throughout the transition, rtl=$rtl', (
      tester,
    ) async {
      var value = false;
      late StateSetter change;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Scaffold(
                body: Center(
                  child: Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: RepaintBoundary(
                      key: capture,
                      child: AppSwitch(
                        value: value,
                        onChanged: (next) => setState(() => value = next),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      final thumb = find.byKey(const ValueKey('app-switch-thumb'));
      final start = tester.getCenter(thumb).dx;
      final size = tester.getSize(thumb);
      Future<void> snapshot(String name) async {
        if (Platform.environment['CAPTURE_SWITCH_UI'] != '1' || rtl) return;
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 4);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/switch-ui').create(recursive: true);
          await File(
            'build/switch-ui/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await snapshot('off');
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final quarter = tester.getCenter(thumb).dx;
      await snapshot('60ms');
      // Parent rebuilds during a transition must not restart the animation.
      change(() {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final middle = tester.getCenter(thumb).dx;
      await snapshot('120ms');
      await tester.pump(const Duration(milliseconds: 60));
      final late = tester.getCenter(thumb).dx;
      await snapshot('180ms');
      await tester.pump(const Duration(milliseconds: 60));
      final end = tester.getCenter(thumb).dx;
      await snapshot('on');
      final direction = rtl ? -1 : 1;
      expect((quarter - start) * direction, greaterThan(0));
      expect((middle - quarter) * direction, greaterThan(0));
      expect((late - middle) * direction, greaterThan(0));
      expect((end - late) * direction, greaterThan(0));
      expect((middle - start).abs(), closeTo((end - start).abs() / 2, 1));
      expect(tester.getSize(thumb), size);
      // Reverse while the pointer remains over the control.
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(tester.getCenter(thumb).dx, closeTo(start, .01));
    });
  }

  testWidgets(
    'hover keeps pixels unchanged; keyboard and semantics can toggle',
    (tester) async {
      var value = false;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: AppSwitch(
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> pixels() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      }

      final before = await tester.runAsync(pixels);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AppSwitch)));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(pixels), before);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(AppSwitch)),
        matchesSemantics(
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, isFalse);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'drag works in both directions and disabled switches ignore input',
    (tester) async {
      var value = false;
      var enabled = true;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Scaffold(
                body: Center(
                  child: AppSwitch(
                    value: value,
                    onChanged: enabled
                        ? (next) => setState(() => value = next)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.drag(find.byType(AppSwitch), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      await tester.drag(find.byType(AppSwitch), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      change(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppSwitch));
      await tester.drag(find.byType(AppSwitch), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(value, isFalse);
    },
  );
}
