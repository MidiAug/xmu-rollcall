import 'package:flutter/material.dart';

/// DSH surfaces, muted steel accent. No loud brand gradients.
class AppPalette {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceHigh,
    required this.content,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.danger,
    required this.border,
    required this.borderStrong,
    required this.hover,
    required this.selected,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceHigh;
  final Color content;
  final Color ink;
  final Color muted;
  final Color primary;
  final Color danger;
  final Color border;
  final Color borderStrong;
  final Color hover;
  final Color selected;

  static AppPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? darkPalette : lightPalette;
  }

  static const darkPalette = AppPalette(
    canvas: Color(0xFF151517),
    surface: Color(0xFF2C2C2E),
    surfaceHigh: Color(0xFF353638),
    content: Color(0xFF18191C),
    ink: Color(0xFFF9FAFB),
    muted: Color(0xFFADB2B8),
    primary: Color(0xFF8B9BB4),
    danger: Color(0xFFE07070),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x1FFFFFFF),
    hover: Color(0x14FFFFFF),
    selected: Color(0x24FFFFFF),
  );

  static const lightPalette = AppPalette(
    canvas: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFECECEF),
    content: Color(0xFFF0F0F2),
    ink: Color(0xFF1C1C1E),
    muted: Color(0xFF6E6E73),
    primary: Color(0xFF5C6E85),
    danger: Color(0xFFC44C4C),
    border: Color(0x14000000),
    borderStrong: Color(0x1F000000),
    hover: Color(0x0A000000),
    selected: Color(0x12000000),
  );
}

abstract final class AppRadii {
  static const input = 10.0;
  static const card = 12.0;
  static const button = 12.0;
  static const dialog = 20.0;
}

abstract final class AppLayout {
  static const shellBreakpoint = 600.0;
  static const sidebarWidth = 220.0;
  static const titleBarHeight = 36.0;
  static const navItemHeight = 40.0;
}
