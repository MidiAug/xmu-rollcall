import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'preview_fonts.dart';

bool get isDesktopUiCaptureEnabled =>
    Platform.environment['CAPTURE_DESKTOP_UI'] == '1' ||
    Platform.environment['CAPTURE_UI'] == '1';

/// Optional local renders, with real fonts; generated PNGs stay out of Git.
Future<void> loadDesktopUiCaptureFonts() async {
  if (!isDesktopUiCaptureEnabled) return;
  final iconFont =
      Platform.environment['DESKTOP_UI_ICONS'] ??
      resolveFlutterMaterialIconsFontPath();
  final fonts = <String, String>{
    'DesktopUi':
        Platform.environment['DESKTOP_UI_FONT'] ?? r'C:\Windows\Fonts\msyh.ttc',
    'MaterialIcons': ?iconFont,
  };
  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (await file.exists()) {
      await (FontLoader(
        entry.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  }
}

class _DesktopUiCaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

/// Capture runs use the binding's supported shadow policy, without changing
/// painting debug variables during a test or weakening its invariant checks.
void initializeDesktopUiCapture() {
  if (isDesktopUiCaptureEnabled) {
    _DesktopUiCaptureBinding();
  }
}

ThemeData desktopCaptureTheme(ThemeData theme) {
  if (!isDesktopUiCaptureEnabled) return theme;
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
  if (!isDesktopUiCaptureEnabled) return;
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
