import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Optional local renders, with real fonts; generated PNGs stay out of Git.
Future<void> loadDesktopUiCaptureFonts() async {
  if (Platform.environment['CAPTURE_DESKTOP_UI'] != '1') return;
  for (final entry in {
    'DesktopUi': Platform.environment['DESKTOP_UI_FONT']!,
    'MaterialIcons': Platform.environment['DESKTOP_UI_ICONS']!,
  }.entries) {
    await (FontLoader(entry.key)
          ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView)))
        .load();
  }
}

ThemeData desktopCaptureTheme(ThemeData theme) {
  if (Platform.environment['CAPTURE_DESKTOP_UI'] != '1') return theme;
  ButtonStyle? font(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStatePropertyAll(
      (style.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
        fontFamily: 'DesktopUi',
      ),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'DesktopUi'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'DesktopUi'),
    filledButtonTheme: FilledButtonThemeData(
      style: font(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: font(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(theme.textButtonTheme.style),
    ),
  );
}

Future<void> captureDesktopUi(WidgetTester tester, String label) async {
  expect(tester.takeException(), isNull);
  if (Platform.environment['CAPTURE_DESKTOP_UI'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        tester
                .element(find.byKey(const ValueKey('desktop-ui-capture')))
                .findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      'build/desktop-ui-review',
    ).create(recursive: true);
    await File(
      '${directory.path}/$label.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
