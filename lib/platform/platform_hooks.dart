import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

abstract final class PlatformHooks {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// Only fresh discoveries, preserving course and type for platform reminders.
  static Future<void> Function(List<RollcallItem> items)? onRollcallsDiscovered;
  static Future<void> Function(RollcallItem item, bool ok)?
  onAutomaticAnswerResult;

  /// Icon for “跟随系统” appearance — matches current form factor.
  static IconData systemAppearanceIcon(BuildContext context) {
    if (kIsWeb) return Icons.language_outlined;
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.macOS:
        return Icons.laptop_mac_outlined;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return Icons.desktop_windows_outlined;
      default:
        break;
    }
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest >= 600) {
      return platform == TargetPlatform.iOS
          ? Icons.tablet_mac_outlined
          : Icons.tablet_android_outlined;
    }
    return Icons.smartphone_outlined;
  }

  static Future<void> initOptional() async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: AppLayout.windowSize,
      minimumSize: AppLayout.windowSize,
      maximumSize: AppLayout.windowSize,
      title: kAppDisplayName,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      // Fixed frame: no resize / maximize (re-assert after ready on some platforms).
      await windowManager.setMinimumSize(AppLayout.windowSize);
      await windowManager.setMaximumSize(AppLayout.windowSize);
      await windowManager.setSize(AppLayout.windowSize);
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
