import 'package:flutter/material.dart';

/// Quiet Utility surfaces: cold neutrals + clear indigo accent.
///
/// Hover is **luminance**, never indigo wash. Light mode sits white cards on
/// gray [canvas] — do **not** darken fills toward canvas (they melt). Prefer:
/// keep white + hairline ([cardHover] ≈ [surface]), or a fill still **lighter**
/// than [canvas] (e.g. [content] / [hover] solid).
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
    required this.cardHover,
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

  /// Inset-row / chrome hover fill. Light: solid, still lighter than [canvas].
  /// Dark: translucent white lift.
  final Color hover;

  /// Elevated card hover fill. Light: same as [surface] (identity via hairline).
  /// Dark: slight lift above [surface].
  final Color cardHover;
  final Color selected;

  /// Transparent twin of [c] so [AnimatedContainer] color lerps stay in-family
  /// (lerping from [Colors.transparent]/black@0 → light gray flashes dark).
  static Color clearOf(Color c) => c.withValues(alpha: 0);

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
    cardHover: Color(0xFF22222A),
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
    // Solid — still lighter than canvas (#F2F2F4); not black@α (that melts).
    hover: Color(0xFFF6F6F8),
    // Stay white; AppHoverSurface / list cards signal via hairline only.
    cardHover: Color(0xFFFFFFFF),
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

  /// Gap between settings caption and its inset card (Cupertino header→rows ≈ 6).
  /// Slightly above 6 so CJK captions don’t sit on the card edge.
  static const sectionGap = 8.0;

  /// Space above a settings group (previous card → next caption).
  /// Mirrors Cupertino insetGrouped header top (~16) with Quiet Utility air.
  static const settingsGroupTop = 28.0;

  /// Narrow-width settings group top gap.
  static const settingsGroupTopCompact = 22.0;

  static double pageXOf(BuildContext context) =>
      AppDensity.isTouch(context) ? pageXCompact : pageX;

  static double stackOf(BuildContext context) =>
      AppDensity.isTouch(context) ? stackCompact : stack;

  static double settingsGroupTopOf(BuildContext context) =>
      AppDensity.isTouch(context) ? settingsGroupTopCompact : settingsGroupTop;
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
  static const desktopRow = 44.0;
  static const touchRow = 44.0;
  static const desktopNav = 40.0;
  static const touchNav = 44.0;
  static const mobileBar = 56.0;

  /// Extra air trimmed from the home-indicator inset under [AppMobileNav]
  /// (see docs/research/18-flutter-mobile-nav-bottom-inset.md).
  static const mobileNavBottomTrim = 8.0;

  static const desktopRowPadH = AppSpace.md;
  static const desktopRowPadV = AppSpace.xs;
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

/// Restrained motion ladder (Quiet Utility visual polish).
///
/// Prefer the named tokens. [duration] / [curve] alias [page] for older call sites.
abstract final class AppMotion {
  /// Selected state, segment thumb, switch thumb.
  static const instant = Duration(milliseconds: 110);
  static const instantCurve = Curves.easeOut;

  /// Hover fill, list-row lift.
  static const fast = Duration(milliseconds: 170);
  static const fastCurve = Curves.easeOutCubic;

  /// Subpage push / pop (slide + fade).
  static const page = Duration(milliseconds: 270);
  static const pageCurve = Curves.easeOutCubic;

  /// First paint / empty-state enter.
  static const enter = Duration(milliseconds: 210);
  static const enterCurve = Curves.easeOut;

  /// Alias of [page] — prefer named tokens in new code.
  static const duration = page;
  static const curve = pageCurve;
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

  /// Desktop list / settings column max width (includes call-site [AppSpace.pageX]).
  /// Touch layouts ignore this and stay full-bleed.
  static const contentMaxWidth = 720.0;

  /// Fixed desktop window size ([PlatformHooks.initOptional]; not resizable).
  /// ≈ sidebar + centered content column with modest chrome.
  static const Size windowSize = Size(960, 720);
}
