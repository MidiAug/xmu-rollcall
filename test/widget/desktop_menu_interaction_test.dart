import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

void main() {
  testWidgets(
    'window buttons respond across their whole area without hover',
    (tester) async {
      final calls = <String>[];
      const channel = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const AppTitleBar(title: 'Test'),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.topRight,
                        child: AppShellSelect<int>(
                          value: 0,
                          items: const [0, 1],
                          labelOf: (v) => 'Option $v',
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final minimize = tester.getRect(find.byTooltip('最小化'));
      await tester.tapAt(minimize.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(calls, contains('minimize'));
      final close = tester.getRect(find.byTooltip('关闭窗口'));
      await tester.tapAt(close.bottomRight - const Offset(4, 4));
      await tester.pump();
      expect(calls, contains('close'));
      Focus.of(tester.element(find.byIcon(Icons.remove))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls.where((call) => call == 'minimize'), hasLength(2));
      await tester.tap(find.byType(AppSelectTrigger));
      await tester.pumpAndSettle();
      await tester.tapAt(minimize.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'minimize'), hasLength(3));
      expect(find.byType(AppMenuOption), findsNothing);
    },
    skip: !PlatformHooks.isDesktop,
  );

  testWidgets('an open menu does not swallow the next control click', (
    tester,
  ) async {
    var actionCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppShellSelect<int>(
                key: const ValueKey('first'),
                value: 0,
                items: const [0, 1],
                labelOf: (v) => 'First $v',
                onChanged: (_) {},
              ),
              const SizedBox(height: 240),
              AppShellSelect<int>(
                key: const ValueKey('second'),
                value: 0,
                items: const [0, 1],
                labelOf: (v) => 'Second $v',
                onChanged: (_) {},
              ),
              const SizedBox(height: 180),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    actionCalls++;
                    AppPageRoutes.push(
                      context,
                      const Scaffold(body: Text('Next page')),
                    );
                  },
                  child: const Text('Next action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('second')));
    await tester.pumpAndSettle();
    expect(find.text('Second 1'), findsOneWidget);
    expect(find.text('First 1'), findsNothing);
    await tester.tap(find.text('Next action'));
    await tester.pumpAndSettle();
    expect(actionCalls, 1);
    expect(find.byType(AppMenuOption), findsNothing);
    expect(find.text('Next page'), findsOneWidget);
    Navigator.of(tester.element(find.text('Next page'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('first')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuOption), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings select opens and commits pointer selection in tab navigator',
    (tester) async {
      var selected = CloseMode.tray;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 220),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => StatefulBuilder(
                        builder: (context, setState) => ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 260),
                            SettingsSection(
                              header: '窗口',
                              children: [
                                SettingsRow(
                                  title: '关闭窗口时',
                                  trailing: AppShellSelect<CloseMode>(
                                    value: selected,
                                    items: CloseMode.values,
                                    labelOf: (m) => m.label,
                                    width: 148,
                                    onChanged: (m) =>
                                        setState(() => selected = m),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 300),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppSelectTrigger));
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuOption), findsNWidgets(3));
      await tester.tap(find.text('每次询问'));
      await tester.pumpAndSettle();
      expect(selected, CloseMode.ask);
      expect(find.byType(AppMenuOption), findsNothing);
      await tester.tap(find.byType(AppSelectTrigger));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最小化到托盘').last);
      await tester.pumpAndSettle();
      expect(selected, CloseMode.tray);
      expect(tester.takeException(), isNull);
    },
  );
}
