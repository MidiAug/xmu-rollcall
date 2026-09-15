import 'package:flutter/material.dart';

/// Quiet steel surfaces. One muted accent; no loud brand gradients.
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
    canvas: Color(0xFF121214),
    surface: Color(0xFF1C1C1F),
    surfaceHigh: Color(0xFF262629),
    content: Color(0xFF161618),
    ink: Color(0xFFF4F4F5),
    muted: Color(0xFFA1A1AA),
    primary: Color(0xFF7B8FA8),
    danger: Color(0xFFD97777),
    border: Color(0x12FFFFFF),
    borderStrong: Color(0x1AFFFFFF),
    hover: Color(0x12FFFFFF),
    selected: Color(0x1FFFFFFF),
  );

  static const lightPalette = AppPalette(
    canvas: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFECECEE),
    content: Color(0xFFF7F7F8),
    ink: Color(0xFF18181B),
    muted: Color(0xFF71717A),
    primary: Color(0xFF556B84),
    danger: Color(0xFFC04444),
    border: Color(0x0F000000),
    borderStrong: Color(0x18000000),
    hover: Color(0x08000000),
    selected: Color(0x10000000),
  );
}

/// 4px base rhythm (Linear / M3-aligned). Prefer these over magic numbers.
abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal inset shared by page header and scroll bodies.
  static const pageX = 24.0;

  /// Gap between stacked panels / list rows.
  static const stack = 12.0;
}

/// One radius ladder for the whole shell (Shape Consistency Lock).
abstract final class AppRadii {
  static const control = 6.0;
  static const input = 8.0;
  static const button = 8.0;
  static const card = 10.0;
  static const nav = 8.0;
  static const dialog = 14.0;
}

abstract final class AppLayout {
  static const shellBreakpoint = 600.0;
  static const sidebarWidth = 228.0;

  /// Desktop window chrome / subpage nav share one bar height (no nested bars).
  static const titleBarHeight = 40.0;
  static const navItemHeight = 36.0;
  static const segmentHeight = 28.0;

  /// Fixed page chrome so Tab switches never shift the title baseline.
  /// Title line (~22) + gap 4 + subtitle line (~18) + vertical padding 16+12.
  static const pageHeaderHeight = 72.0;

  /// Wide enough for「清空」TextButton; empty tabs keep the same slot.
  static const pageHeaderTrailingWidth = 72.0;
}
