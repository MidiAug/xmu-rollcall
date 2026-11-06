import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  for (final width in [960.0, 1920.0]) {
    for (final rtl in [false, true]) {
      testWidgets('desktop navigation stays local at $width rtl=$rtl', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? result;
        final field = TextEditingController(text: '保留的搜索');
        addTearDown(field.dispose);
        await tester.pumpWidget(
          _app(rtl: rtl, field: field, onResult: (value) => result = value),
        );
        await tester.tap(find.text('打开详情'));
        await tester.pump();
        await tester.pump();
        final destination = find.byKey(const ValueKey('route-destination'));
        final initial = tester.getTopLeft(destination).dx;
        expect(initial, closeTo(rtl ? -16 : 16, .1));
        await tester.pump(const Duration(milliseconds: 70));
        final during = tester.getTopLeft(destination).dx;
        expect(during.abs(), lessThan(initial.abs()));
        expect(during.abs(), greaterThan(0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(destination), Offset.zero);
        await tester.tap(find.text('完成并返回'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final returning = tester.getTopLeft(destination).dx;
        expect(returning.abs(), inExclusiveRange(0, 16));
        expect(
          returning.abs(),
          greaterThan(4),
          reason: 'return starts promptly',
        );
        expect(returning.isNegative, rtl);
        await tester.pumpAndSettle();
        expect(result, 'finished');
        expect(find.text('保留的搜索'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('an opening subpage can reverse from its current position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final field = TextEditingController(text: '保留的输入');
    addTearDown(field.dispose);
    String? result;
    await tester.pumpWidget(_app(field: field, onResult: (v) => result = v));
    await tester.tap(find.text('打开详情'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final destination = find.byKey(const ValueKey('route-destination'));
    final before = tester.getTopLeft(destination);
    await tester.tap(find.text('完成并返回'));
    await tester.pump();
    expect(tester.getTopLeft(destination).dx, closeTo(before.dx, .1));
    await tester.pumpAndSettle();
    expect(destination, findsNothing);
    expect(result, 'finished');
    expect(find.text('保留的输入'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion presents and returns without a transition wait', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final field = TextEditingController(text: '原有输入');
    addTearDown(field.dispose);
    String? result;
    await tester.pumpWidget(
      _app(reduced: true, field: field, onResult: (value) => result = value),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pump();
    final destination = find.byKey(const ValueKey('route-destination'));
    expect(tester.getTopLeft(destination), Offset.zero);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, false);
    await tester.tap(find.text('完成并返回'));
    await tester.pump();
    await tester.pump();
    expect(destination, findsNothing);
    expect(result, 'finished');
    expect(find.text('原有输入'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app({
  bool rtl = false,
  bool reduced = false,
  required TextEditingController field,
  required ValueChanged<String?> onResult,
}) => MaterialApp(
  theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Column(
        children: [
          TextField(controller: field),
          TextButton(
            onPressed: () async {
              final result = await AppPageRoutes.push<String>(
                context,
                const _Destination(),
              );
              onResult(result);
            },
            child: const Text('打开详情'),
          ),
        ],
      ),
    ),
  ),
);

class _Destination extends StatelessWidget {
  const _Destination();
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('route-destination'),
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pop('finished'),
        child: const Text('完成并返回'),
      ),
    ),
  );
}
