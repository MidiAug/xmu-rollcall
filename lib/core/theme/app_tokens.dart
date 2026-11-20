import 'package:flutter/material.dart';
export 'app_icons.dart';
export 'app_typography.dart';

/// Neutral porcelain and graphite surfaces, with distinct semantic states.
/// Text/graphic success colors are separate so bright status accents retain
/// readable labels. Hover surfaces interpolate within opaque theme colors.
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

  /// Inset-row / chrome hover fill. Light: a solid, neutral gray.
  /// Dark: translucent white lift.
  final Color hover;

  /// Elevated card hover fill, independent of the navigation selection.
  /// Dark: slight lift above [surface].
  final Color cardHover;
  final Color selected;
  bool get isDark =>
      ThemeData.estimateBrightnessForColor(canvas) == Brightness.dark;
  Color get sidebar =>
      isDark ? const Color(0xFF1D2027) : const Color(0xFFEEF0F4);
  Color get window =>
      isDark ? const Color(0xFF1C1F26) : const Color(0xFFF0F2F5);
  Color get success =>
      isDark ? const Color(0xFF69D99D) : const Color(0xFF007A46);
  Color get successAccent =>
      isDark ? const Color(0xFF49DB92) : const Color(0xFF00B66A);
  Color get successSurface =>
      isDark ? const Color(0xFF173D30) : const Color(0xFFE4FAED);
  Color get navigationAccent => primary;
  // Sidebar gray is darker than the content canvas; generic hover nearly
  // disappears on it. Keep navigation feedback distinct from white selection.
  Color get navigationHover => isDark ? hover : const Color(0xFFDFE5EE);

  /// Ink paints over the existing surface. An opaque surface token would erase
  /// a selected background while leaving its contrasting text unchanged.
  Color get hoverOverlay => isDark
      ? Colors.white.withValues(alpha: .06)
      : ink.withValues(alpha: .045);
  Color get primaryHover => Color.lerp(primary, ink, .12)!;
  Color get primaryPressed => Color.lerp(primary, ink, .2)!;

  /// Action surfaces stay distinct from the canvas even under the pointer.
  Color get controlHover => isDark ? const Color(0xFF353D4C) : hover;
  Color get controlPressed =>
      isDark ? const Color(0xFF3D485C) : const Color(0xFFE0E5ED);

  /// Document / assignment icon badge tokens shared across summary cards.
  Color get documentSurface =>
      isDark ? const Color(0xFF163D57) : const Color(0xFFE7F4FF);
  Color get documentAccent =>
      isDark ? const Color(0xFF70BEFF) : const Color(0xFF087CE5);

  /// Focus follows the active theme accent; it is not a separate blue palette.
  Color get focus => primary;

  /// Teaching dates and academic data share an accent, separate from chrome.
  Color get dataAccent =>
      isDark ? const Color(0xFF8AB4FF) : const Color(0xFF0066CC);
  Color get warning =>
      isDark ? const Color(0xFFE6BD7C) : const Color(0xFF9B6B26);

  /// Touch pages separate the canvas, content cards and actionable controls.
  Color get mobileCanvas =>
      isDark ? const Color(0xFF17191F) : const Color(0xFFF4F5F7);
  Color get mobileOutline =>
      isDark ? const Color(0xFF3C414D) : const Color(0xFFDCE0E7);
  Color get controlSurface =>
      isDark ? const Color(0xFF303540) : const Color(0xFFEBEEF3);
  Color get accentSurface =>
      isDark ? const Color(0xFF343C4C) : const Color(0xFFE8ECF3);
  Color pageBackground(BuildContext context) {
    final mobile = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => AppDensity.isTouch(context),
    };
    return mobile ? mobileCanvas : canvas;
  }

  /// Transparent twin of [c] so [AnimatedContainer] color lerps stay in-family
  /// (lerping from [Colors.transparent]/black@0 → light gray flashes dark).
  static Color clearOf(Color c) => c.withValues(alpha: 0);

  static AppPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? darkPalette : lightPalette;
  }

  static const darkPalette = AppPalette(
    canvas: Color(0xFF17191F),
    surface: Color(0xFF24272F),
    surfaceHigh: Color(0xFF30343F),
    content: Color(0xFF20232B),
    ink: Color(0xFFECEEF4),
    muted: Color(0xFFA6ADBC),
    primary: Color(0xFFA6C5FF),
    danger: Color(0xFFD97777),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x22FFFFFF),
    hover: Color(0xFF2B2F39),
    cardHover: Color(0xFF2B2F39),
    selected: Color(0xFF343A47),
  );

  static const lightPalette = AppPalette(
    canvas: Color(0xFFFAFBFD),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEEF0F4),
    content: Color(0xFFF0F2F6),
    ink: Color(0xFF23262D),
    muted: Color(0xFF626B79),
    // The reference blue is deepened to keep small labels and white actions
    // readable; navigation and actions still share one semantic accent.
    primary: Color(0xFF2166DB),
    danger: Color(0xFFC04444),
    border: Color(0xFFE5E9F0),
    borderStrong: Color(0xFFD4DBE5),
    // Solid, with no dark overlay on the light canvas.
    hover: Color(0xFFE9EDF3),
    cardHover: Color(0xFFF5F6F8),
    selected: Color(0xFFE7EDF7),
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
  static const settingsGroupTop = 24.0;

  /// Narrow-width settings group top gap.
  static const settingsGroupTopCompact = 22.0;

  static double pageXOf(BuildContext context) =>
      AppDensity.isTouch(context) ? pageXCompact : pageX;

  static double stackOf(BuildContext context) =>
      AppDensity.isTouch(context) ? stackCompact : stack;

  static double settingsGroupTopOf(BuildContext context) =>
      AppDensity.isTouch(context) ? settingsGroupTopCompact : settingsGroupTop;
}

/// Controls, grouped content and overlays have distinct corner scales.
abstract final class AppRadii {
  static const island = 26.0;
  static const service = 16.0;
  static const control = 10.0;
  static const input = 10.0;
  static const button = 10.0;
  static const nav = 10.0;
  static const card = 16.0;
  static const group = 16.0;
  static const dialog = 20.0;
}

/// Shares the density breakpoint while layout keeps following live constraints.
/// A geometry override, such as a retained tab, needs its own scope below it.
class AppDensityScope extends StatelessWidget {
  const AppDensityScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => _AppDensityData(
    touch: MediaQuery.sizeOf(context).width < AppLayout.shellBreakpoint,
    child: child,
  );
}

class _AppDensityData extends InheritedWidget {
  const _AppDensityData({required this.touch, required super.child});
  final bool touch;
  @override
  bool updateShouldNotify(_AppDensityData oldWidget) =>
      touch != oldWidget.touch;
}

/// Desktop vs touch density (breakpoint = [AppLayout.shellBreakpoint]).
///
/// Narrow layouts use tighter settings/list density so vertical space isn't
/// wasted; navigation stays slightly taller for thumb targets.
abstract final class AppDensity {
  static double controlHeight(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.android || TargetPlatform.iOS => 44,
        _ => 40,
      };
  static const desktopRow = 44.0;
  static const touchRow = 44.0;
  static const desktopNav = 40.0;
  static const touchNav = 44.0;
  static const mobileBar = 56.0;

  /// Small trim from the home-indicator inset under [AppMobileNav]
  /// (see docs/research/18-flutter-mobile-nav-bottom-inset.md).
  static const mobileNavBottomTrim = 2.0;

  static const desktopRowPadH = AppSpace.md;
  static const desktopRowPadV = AppSpace.xxs;
  static const touchRowPadH = AppSpace.sm;
  static const touchRowPadV = AppSpace.xs;
  static const settingsRowMinHeight = 48.0;
  static const settingsLeading = 24.0;
  static const settingsTouchLeading = 36.0;
  static const settingsInnerGap = AppSpace.sm;

  static bool isTouch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppDensityData>()?.touch ??
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
  /// Selected state and segment thumb.
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
  static const sidebarWidth = 184.0;
  static double sidebarWidthOf(BuildContext context) {
    final extraText =
        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 1) * 72;
    return (MediaQuery.sizeOf(context).width * .16 + extraText).clamp(144, 240);
  }

  /// Native window bar height; content headers have their own layout.
  static const titleBarHeight = 32.0;

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

  /// Initial desktop size; native resize is bounded by [minimumWindowSize].
  static const Size windowSize = Size(1120, 780);
  static const Size minimumWindowSize = Size(900, 640);
}
