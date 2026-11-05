import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mouseBack(WidgetTester tester) async {
  await tester.sendEventToBinding(
    const PointerDownEvent(
      pointer: 1,
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
      position: Offset(100, 100),
    ),
  );
  await tester.sendEventToBinding(
    const PointerUpEvent(
      pointer: 1,
      kind: PointerDeviceKind.mouse,
      position: Offset(100, 100),
    ),
  );
  await tester.pumpAndSettle();
}
