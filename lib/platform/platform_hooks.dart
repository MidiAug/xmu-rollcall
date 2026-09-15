import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

abstract final class PlatformHooks {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Icon for “跟随系统” appearance — matches current form factor.
  static IconData systemAppearanceIcon(BuildContext context) {
    if (kIsWeb) return Icons.language_outlined;
    if (isDesktop) {
      if (Platform.isMacOS) return Icons.laptop_mac_outlined;
      return Icons.desktop_windows_outlined;
    }
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest >= 600) {
      return Platform.isIOS
          ? Icons.tablet_mac_outlined
          : Icons.tablet_android_outlined;
    }
    return Icons.smartphone_outlined;
  }

  static Future<void> initOptional() async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(720, 520),
      title: '畅课签到',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
