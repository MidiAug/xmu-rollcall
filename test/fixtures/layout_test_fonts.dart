import 'dart:io';

import 'package:flutter/services.dart';

/// Fixed text metrics for tests that explicitly exercise real text layout.
/// Aliases cover the app's platform families without changing production themes.
Future<void> loadLayoutTestFonts() async {
  final bytes = ByteData.sublistView(
    await File('test/fixtures/fonts/NotoSansSC-Regular.otf').readAsBytes(),
  );
  for (final family in const [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'PingFang SC',
    'Segoe UI',
    'Roboto',
    'Consolas',
  ]) {
    await (FontLoader(family)..addFont(Future.value(bytes))).load();
  }
}
