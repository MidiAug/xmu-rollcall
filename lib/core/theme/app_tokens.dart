import 'package:flutter/material.dart';

/// Quiet Utility surfaces: cold neutrals + clear indigo accent.
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
    canvas: Color(0xFF0F0F12),
    surface: Color(0xFF1A1A1F),
    surfaceHigh: Color(0xFF24242A),
    content: Color(0xFF141418),
    ink: Color(0xFFF4F4F5),
    muted: Color(0xFFA1A1AA),
    primary: Color(0xFF6B8AFF),
    danger: Color(0xFFD97777),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x22FFFFFF),
    hover: Color(0x14FFFFFF),
    selected: Color(0x286B8AFF),
  );

  static const lightPalette = AppPalette(
    canvas: Color(0xFFF2F2F4),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE8E8EC),
    content: Color(0xFFF6F6F8),
    ink: Color(0xFF18181B),
    muted: Color(0xFF71717A),
    primary: Color(0xFF3D5AFE),
    danger: Color(0xFFC04444),
    border: Color(0x0F000000),
    borderStrong: Color(0x18000000),
    hover: Color(0x0A000000),
    selected: Color(0x1A3D5AFE),
  );
}

/// 4px base rhythm. Prefer these over magic numbers.
abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal inset shared by page header and scroll bodies (desktop).
  static const pageX = 24.0;

  /// Narrow-width page inset (`width < [AppLayout.shellBreakpoint]`).
  static const pageXCompact = 16.0;

  /// Gap between stacked sections / panels (desktop).
  static const stack = 20.0;

  /// Narrow-width section stack gap.
  static const stackCompact = 14.0;

  /// Gap between section header and inset group.
  static const sectionGap = 6.0;

  static double pageXOf(BuildContext context) =>
      AppDensity.isTouch(context) ? pageXCompact : pageX;

  static double stackOf(BuildContext context) =>
      AppDensity.isTouch(context) ? stackCompact : stack;
}

/// Concentric radius ladder (Quiet Utility).
abstract final class AppRadii {
  static const control = 10.0;
  static const input = 12.0;
  static const button = 12.0;
  static const nav = 12.0;
  static const card = 14.0;
  static const group = 16.0;
  static const dialog = 20.0;
}

/// Desktop vs touch density (breakpoint = [AppLayout.shellBreakpoint]).
///
/// Narrow layouts use **tighter** settings/list density so vertical space
/// isn't wasted; nav stays slightly taller for thumb targets.
abstract final class AppDensity {
  static const desktopRow = 52.0;
  static const touchRow = 48.0;
  static const desktopNav = 40.0;
  static const touchNav = 44.0;
  static const mobileBar = 56.0;

  /// Extra air trimmed from the home-indicator inset under [AppMobileNav]
  /// (see docs/research/18-flutter-mobile-nav-bottom-inset.md).
  static const mobileNavBottomTrim = 8.0;

  static const desktopRowPadH = AppSpace.md;
  static const desktopRowPadV = AppSpace.sm;
  static const touchRowPadH = AppSpace.sm;
  static const touchRowPadV = AppSpace.xs;

  static bool isTouch(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppLayout.shellBreakpoint;

  static double rowHeight(BuildContext context) =>
      isTouch(context) ? touchRow : desktopRow;

  static double navItemHeight(BuildContext context) =>
      isTouch(context) ? touchNav : desktopNav;

  /// Bottom inset for custom tab bar: full [viewPadding.bottom] minus a small trim.
  static double mobileNavBottomInset(BuildContext context) {
    final v = MediaQuery.viewPaddingOf(context).bottom;
    if (v <= 0) return 0;
    return (v - mobileNavBottomTrim).clamp(0.0, v);
  }

  static EdgeInsets rowPadding(BuildContext context) => isTouch(context)
      ? const EdgeInsets.symmetric(
          horizontal: touchRowPadH,
          vertical: touchRowPadV,
        )
      : const EdgeInsets.symmetric(
          horizontal: desktopRowPadH,
          vertical: desktopRowPadV,
        );

  /// Leading/trailing gap inside [SettingsRow]-style rows.
  static double rowInnerGap(BuildContext context) =>
      isTouch(context) ? AppSpace.sm : AppSpace.md;
}

/// Restrained motion — navigation / enter only.
abstract final class AppMotion {
  static const duration = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppLayout {
  static const shellBreakpoint = 600.0;
  static const sidebarWidth = 228.0;

  /// Desktop window chrome / subpage nav share one bar height (no nested bars).
  static const titleBarHeight = 40.0;

  /// Prefer [AppDensity.navItemHeight]; kept for callers that need a constant.
  static const navItemHeight = AppDensity.desktopNav;
  static const segmentHeight = 28.0;

  /// Fixed page chrome so Tab switches never shift the title baseline.
  /// Title line (~22) + gap 4 + subtitle line (~18) + vertical padding 16+12.
  static const pageHeaderHeight = 72.0;

  /// Wide enough for「清空」TextButton; empty tabs keep the same slot.
  static const pageHeaderTrailingWidth = 72.0;
}
