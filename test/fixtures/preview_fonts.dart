import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'layout_test_fonts.dart';

/// Existing layout suites use portable fonts by default. Explicit CAPTURE_*
/// runs keep Windows fonts for native visual review, outside the CI baseline.
Future<void> loadDesktopPreviewFonts() async {
  final capturing = Platform.environment.entries.any(
    (entry) => entry.key.startsWith('CAPTURE_') && entry.value == '1',
  );
  if (capturing) {
    await _loadWindowsPreviewFonts();
  } else {
    await loadLayoutTestFonts();
  }
  await _loadIconFonts();
}

Future<void> _loadWindowsPreviewFonts() async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Native preview fonts require Windows.');
  }
  for (final path in const [
    'C:/Windows/Fonts/msyh.ttc',
    'C:/Windows/Fonts/segoeui.ttf',
    'C:/Windows/Fonts/consola.ttf',
  ]) {
    if (!File(path).existsSync()) {
      throw StateError('Required native preview font is missing: $path');
    }
  }
  await _loadWindowsTextFonts();
}

String? resolveFlutterSdkPath() {
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null &&
      envRoot.isNotEmpty &&
      Directory(envRoot).existsSync()) {
    return envRoot;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final iconFont = File(
      '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (iconFont.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  final fvmSdk = Directory('.fvm/flutter_sdk');
  if (fvmSdk.existsSync()) {
    return fvmSdk.path;
  }
  return null;
}

String? resolveFlutterMaterialIconsFontPath() {
  final sdk = resolveFlutterSdkPath();
  if (sdk == null) return null;
  final font = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  return font.existsSync() ? font.path : null;
}

Future<void> _loadIconFonts() async {
  final materialIconsPath = resolveFlutterMaterialIconsFontPath();
  if (materialIconsPath != null) {
    await (FontLoader('MaterialIcons')..addFont(
          File(materialIconsPath).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
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

Future<void> _loadWindowsTextFonts() async {
  for (final entry in {
    'Microsoft YaHei UI': [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'Noto Sans CJK SC': [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'Consolas': [
      'C:/Windows/Fonts/consola.ttf',
      'C:/Windows/Fonts/consolab.ttf',
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
}
