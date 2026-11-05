import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/retained_tab_viewport.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  testWidgets('density rebuilds at the breakpoint, not at every resize pixel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var builds = 0;
    final child = Builder(
      builder: (context) {
        builds++;
        return Text(AppDensity.isTouch(context) ? 'touch' : 'desktop');
      },
    );
    await tester.pumpWidget(
      MaterialApp(builder: (context, _) => AppDensityScope(child: child)),
    );
    final initial = builds;
    for (final width in [1100.0, 1000.0, 900.0, AppLayout.shellBreakpoint]) {
      tester.view.physicalSize = Size(width, 740);
      await tester.pump();
    }
    expect(builds, initial);
    expect(find.text('desktop'), findsOneWidget);
    tester.view.physicalSize = const Size(AppLayout.shellBreakpoint - 1, 740);
    await tester.pump();
    expect(builds, initial + 1);
    expect(find.text('touch'), findsOneWidget);
    tester.view.physicalSize = const Size(1200, 740);
    await tester.pump();
    expect(builds, initial + 2);
    expect(find.text('desktop'), findsOneWidget);
  });

  testWidgets(
    'hidden tabs keep density consistent with their retained geometry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var active = 0;
      late StateSetter select;
      final densities = <int, bool>{};
      final children = List.generate(
        2,
        (i) => Builder(
          builder: (context) {
            densities[i] = AppDensity.isTouch(context);
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AppDensityScope(child: child!),
          home: StatefulBuilder(
            builder: (context, set) {
              select = set;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < 2; i++)
                    RetainedTabViewport(
                      active: active == i,
                      child: children[i],
                    ),
                ],
              );
            },
          ),
        ),
      );
      select(() => active = 1);
      await tester.pump();
      tester.view.physicalSize = const Size(500, 740);
      await tester.pump();
      expect(densities, {0: false, 1: true});
      select(() => active = 0);
      await tester.pump();
      expect(densities[0], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scope preserves theme and text scaling updates', (tester) async {
    final data = ValueNotifier(false);
    addTearDown(data.dispose);
    final child = Builder(
      builder: (context) => Text(
        '${Theme.of(context).brightness.name}/${MediaQuery.textScalerOf(context).scale(10)}',
      ),
    );
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: data,
        builder: (context, dark, _) => MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(dark ? 1.5 : 1)),
            child: AppDensityScope(child: child),
          ),
        ),
      ),
    );
    expect(find.text('light/10.0'), findsOneWidget);
    data.value = true;
    await tester.pumpAndSettle();
    expect(find.text('dark/15.0'), findsOneWidget);
  });

  testWidgets(
    'standalone components use their local MediaQuery without a scope',
    (tester) async {
      Widget page(double width) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 740)),
          child: Builder(
            builder: (context) =>
                Text(AppDensity.isTouch(context) ? 'touch' : 'desktop'),
          ),
        ),
      );
      await tester.pumpWidget(page(1200));
      expect(find.text('desktop'), findsOneWidget);
      await tester.pumpWidget(page(500));
      expect(find.text('touch'), findsOneWidget);
    },
  );
}
