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
  // Camera framing remains a dark scene in both themes.
  Color get scannerCanvas => const Color(0xFF141B28);
  Color get scannerInk => const Color(0xFFC1CCDC);
  Color get scannerAccent => const Color(0xFF4B8FF7);
  Color get scannerControl => const Color(0xFF394150);
  Color get sidebar =>
      isDark ? const Color(0xFF1D2027) : const Color(0xFFEAEFF5);
  Color get sidebarBorder =>
      isDark ? const Color(0xFF343A47) : const Color(0xFFDCE2EC);
  Color get inkBody =>
      isDark ? const Color(0xFFDCE2EE) : const Color(0xFF1E2534);
  // Decorative/disabled details only; readable metadata uses muted.
  Color get subtle =>
      isDark ? const Color(0xFF8995AC) : const Color(0xFF8691A5);
  Color get insetSurface =>
      isDark ? const Color(0xFF202630) : const Color(0xFFF6F8FB);
  Color get surfaceRim => border;
  Color get divider =>
      isDark ? const Color(0xFF343A47) : const Color(0xFFECEFF5);
  Color get track => isDark ? const Color(0xFF202630) : const Color(0xFFE5E9F2);
  Color get trackRim =>
      isDark ? const Color(0xFF414B5D) : const Color(0xFFD8DFEC);
  Color get controlRim =>
      isDark ? const Color(0xFF505B70) : const Color(0xFFD8E0EC);
  Color get btnBorder =>
      isDark ? const Color(0xFF505B70) : const Color(0xFFD4DCE9);
  Color get pillMuted =>
      isDark ? const Color(0xFF303743) : const Color(0xFFF0F3F8);
  Color get accentSoft =>
      isDark ? const Color(0xFF223653) : const Color(0xFFEBF2FE);
  Color get accentRim =>
      isDark ? const Color(0xFF3C5B88) : const Color(0xFFCFDEF9);
  Color get weekBandRim =>
      isDark ? const Color(0xFF3C5B88) : const Color(0xFFD2E1FA);
  Color get heroRim =>
      isDark ? const Color(0xFF3C5276) : const Color(0xFFD4E2FA);
  List<Color> get heroColors => isDark
      ? const [Color(0xFF242C3A), Color(0xFF25344B), Color(0xFF243D5F)]
      : const [Color(0xFFFFFFFF), Color(0xFFF6F9FF), Color(0xFFE9F1FE)];
  Color get subWell =>
      isDark ? const Color(0xCC202B3D) : const Color(0xCCFFFFFF);
  Color get subWellRim =>
      isDark ? const Color(0xFF465B7A) : const Color(0xFFFFFFFF);
  List<Color> get iconWellColors => isDark
      ? const [Color(0xFF293A54), Color(0xFF24344F)]
      : const [Color(0xFFF4F8FF), Color(0xFFE8F0FE)];
  Color get iconWellRim =>
      isDark ? const Color(0xFF415D86) : const Color(0xFFD6E4FB);
  Color get successRim =>
      isDark ? const Color(0xFF32674E) : const Color(0xFFC5EBD6);
  Color get dangerSoft =>
      isDark ? const Color(0xFF3B242B) : const Color(0xFFFDF0F0);
  Color get dangerRim =>
      isDark ? const Color(0xFF79444E) : const Color(0xFFF5D0D0);
  Color get badgeRim =>
      isDark ? const Color(0xFF505B70) : const Color(0xFFD8E0EC);
  Color get window =>
      isDark ? const Color(0xFF1C1F26) : const Color(0xFFF0F2F5);
  Color get success =>
      isDark ? const Color(0xFF69D99D) : const Color(0xFF047847);
  Color get successAccent =>
      isDark ? const Color(0xFF49DB92) : const Color(0xFF00B66A);
  Color get successSurface =>
      isDark ? const Color(0xFF173D30) : const Color(0xFFE8F6EE);
  Color get navigationAccent => primary;
  // Sidebar gray is darker than the content canvas; generic hover nearly
  // disappears on it. Keep navigation feedback distinct from white selection.
  Color get navigationHover =>
      isDark ? const Color(0xFF2A2E38) : const Color(0xFFE5E7EC);
  Color get navigationPressed =>
      isDark ? const Color(0xFF333845) : const Color(0xFFDBDDE3);

  /// Elevated container surface for popovers, menus, dialogs and sheets.
  Color get popoverSurface => isDark ? const Color(0xFF2A2E38) : surface;
  Color get popoverBorder => isDark
      ? Colors.white.withValues(alpha: .13)
      : Colors.black.withValues(alpha: .08);
  Color get surfaceBorder => surfaceRim;
  Color get switchTrackOff =>
      isDark ? const Color(0xFF393E4A) : const Color(0xFFD0D5DD);

  /// Ink paints over the existing surface. An opaque surface token would erase
  /// a selected background while leaving its contrasting text unchanged.
  Color get hoverOverlay => isDark
      ? Colors.white.withValues(alpha: .06)
      : ink.withValues(alpha: .045);
  Color get primaryHover => Color.lerp(primary, ink, .12)!;
  Color get primaryPressed => Color.lerp(primary, ink, .2)!;

  /// Action surfaces stay distinct from the canvas even under the pointer.
  Color get controlHover => isDark ? const Color(0xFF353A47) : hover;
  Color get controlPressed =>
      isDark ? const Color(0xFF3F4554) : const Color(0xFFDFE1E6);

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
      isDark ? const Color(0xFF17191F) : const Color(0xFFF2F4F8);
  Color get mobileOutline =>
      isDark ? const Color(0xFF3C414D) : const Color(0xFFDCE0E7);
  Color get controlSurface =>
      isDark ? const Color(0xFF2C303B) : const Color(0xFFF3F5F8);
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
    primary: Color(0xFF70AAFF),
    danger: Color(0xFFD97777),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x22FFFFFF),
    hover: Color(0xFF353A47),
    cardHover: Color(0xFF2F333E),
    selected: Color(0xFF303543),
  );

  static const lightPalette = AppPalette(
    canvas: Color(0xFFF3F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEAEFF5),
    content: Color(0xFFF0F2F6),
    ink: Color(0xFF121826),
    muted: Color(0xFF5E697C),
    // R17–R25 light reference; actions and navigation share this accent.
    primary: Color(0xFF1F64DB),
    danger: Color(0xFFC53030),
    border: Color(0xFFDFE5F0),
    borderStrong: Color(0xFFD8E0EC),
    // Solid, with no dark overlay on the light canvas.
    hover: Color(0xFFEAECEF),
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
  static const hero = 24.0;
  static const subWell = 16.0;
  static const segmentTrack = 12.0;
  static const segmentThumb = 9.0;
  static const service = 22.0;
  static const control = 12.0;
  static const input = 12.0;
  static const button = 12.0;
  static const nav = 12.0;
  static const card = 20.0;
  static const group = 20.0;
  static const dialog = 24.0;
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

  /// Reading/form and data-workspace widths include the page insets.
  /// Touch layouts ignore these limits and stay full-bleed.
  static const readingMaxWidth = 720.0;
  static const workspaceMaxWidth = 960.0;
  static const contentMaxWidth = readingMaxWidth;

  /// Initial desktop size; native resize is bounded by [minimumWindowSize].
  static const Size windowSize = Size(1120, 780);
  static const Size minimumWindowSize = Size(900, 640);
}

/// Stable course identity hues; surfaces pair each hue with theme-aware ink.
abstract final class AppCourseColors {
  static const accents = <Color>[
    Color(0xFFE86A8A), // rose
    Color(0xFF8B7CF6), // lavender
    Color(0xFFF09A4A), // apricot
    Color(0xFF5BA8E0), // sky
    Color(0xFF5CB89A), // mint
    Color(0xFFD4A017), // gold
    Color(0xFFC77DCF), // orchid
    Color(0xFF6B9BD1), // soft blue
    Color(0xFFE07A5F), // coral
    Color(0xFF4DB6A0), // teal
    Color(0xFFB07CC6), // lilac
    Color(0xFF7EB56A), // leaf
    Color(0xFFE8A0B0), // blush
    Color(0xFF5C8AD6), // cornflower
    Color(0xFFD4925A), // sand
    Color(0xFF6CB5C9), // aqua
    Color(0xFFC96B8A), // raspberry
    Color(0xFF8A9AE0), // periwinkle
    Color(0xFFC9A227), // mustard
    Color(0xFF6AAB8E), // sage
  ];
}
