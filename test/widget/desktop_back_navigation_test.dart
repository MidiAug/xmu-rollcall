import 'package:xmu_rollcall/app/chrome.dart';
import '../fixtures/desktop_back_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/desktop_back_navigation.dart';

void main() {
  for (final mouse in [false, true]) {
    testWidgets(
      'back closes a menu before its page and stays at root mouse=$mouse',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(platform: TargetPlatform.windows),
            builder: (context, child) =>
                DesktopBackNavigation(navigatorKey: navigator, child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        body: Center(
                          child: AppShellSelect<bool>(
                            value: false,
                            items: const [false, true],
                            labelOf: (v) => v ? '进行中' : '全部',
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('打开页面'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开页面'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('全部'));
        await tester.pumpAndSettle();
        expect(find.text('进行中'), findsOneWidget);
        Future<void> back() async {
          if (mouse) {
            await mouseBack(tester);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
        }

        await back();
        expect(find.text('进行中'), findsNothing);
        expect(find.byType(AppShellSelect<bool>), findsOneWidget);
        await back();
        expect(find.byType(AppShellSelect<bool>), findsNothing);
        await back();
        expect(find.text('打开页面'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final mouse in [false, true]) {
    testWidgets('desktop back respects dialog inner steps mouse=$mouse', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      var map = true;
      var guarded = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: TargetPlatform.windows),
          builder: (context, child) =>
              DesktopBackNavigation(navigatorKey: navigator, child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => StatefulBuilder(
                    builder: (context, update) => PopScope(
                      canPop: !map,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop && map) {
                          guarded++;
                          update(() => map = false);
                        }
                      },
                      child: AlertDialog(content: Text(map ? '地图步骤' : '课程步骤')),
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      Future<void> back() async {
        if (mouse) {
          await mouseBack(tester);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      await back();
      expect(guarded, 1);
      expect(find.text('课程步骤'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await back();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
