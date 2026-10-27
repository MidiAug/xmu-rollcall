import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/retained_tab_viewport.dart';

void main() {
  testWidgets('IndexedStack baseline relayouts all visited tabs on resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var layouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IndexedStack(
          index: 0,
          children: [
            for (var i = 0; i < 5; i++) _Counter(onLayout: (_) => layouts++),
          ],
        ),
      ),
    );
    layouts = 0;
    for (var i = 0; i < 60; i++) {
      tester.view.physicalSize = Size(1001.0 + i * 3, 701.0 + i);
      await tester.pump();
    }
    expect(layouts, 300);
    debugPrint(
      'IndexedStack baseline: 60 resizes / 5 visited tabs = $layouts layouts',
    );
  });
  testWidgets(
    'resize skips hidden layouts and keeps route state and geometry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var active = 0;
      late StateSetter select;
      final layouts = List.filled(5, 0);
      final mediaSizes = <int, Size>{};
      final children = List.generate(
        5,
        (i) => _Counter(
          key: ValueKey(i),
          onLayout: (size) {
            layouts[i]++;
            mediaSizes[i] = size;
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              select = set;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < 5; i++)
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
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      select(() => active = 1);
      await tester.pump();
      final before = List.of(layouts);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        tester.view.physicalSize = Size(1001.0 + i * 3, 701.0 + i);
        await tester.pump();
      }
      watch.stop();
      for (var i = 0; i < 5; i++) {
        expect(layouts[i] - before[i], i == 1 ? 60 : 0);
      }
      debugPrint(
        '60 resizes / 5 retained tabs: active layouts=60, hidden=0; '
        'test elapsed=${watch.elapsedMilliseconds}ms (not native frame timing)',
      );
      expect(mediaSizes[0], const Size(1000, 700));
      select(() => active = 0);
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      expect(mediaSizes[0], tester.view.physicalSize);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.onLayout});
  final ValueChanged<Size> onLayout;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var count = 0;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.onLayout(media);
        return Center(
          child: TextButton(
            onPressed: () => setState(() => count++),
            child: Text('Count $count'),
          ),
        );
      },
    );
  }
}
