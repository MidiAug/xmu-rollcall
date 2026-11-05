import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Use the actual desktop font families, plus the package's own icon font.
/// These are local QA fonts, never copied into the distributable assets.
Future<void> loadDesktopPreviewFonts() async {
  for (final entry in {
    'Microsoft YaHei UI': [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'Noto Sans CJK SC': [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'Segoe UI': [
      'C:/Windows/Fonts/segoeui.ttf',
      'C:/Windows/Fonts/seguisb.ttf',
      'C:/Windows/Fonts/segoeuib.ttf',
    ],
  }.entries) {
    final fonts = entry.value.where((p) => File(p).existsSync()).toList();
    if (fonts.isEmpty) continue;
    final loader = FontLoader(entry.key);
    for (final path in fonts) {
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map;
  for (final package in config['packages'] as List) {
    if (package['name'] == 'cupertino_icons') {
      final uri = Uri.parse(package['rootUri'] as String);
      final dir = uri.isAbsolute
          ? Directory.fromUri(uri).path
          : Directory('.dart_tool/${package['rootUri']}').absolute.path;
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            File(
              '$dir/assets/CupertinoIcons.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      continue;
    }
  }
}
