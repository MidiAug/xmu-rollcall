import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

abstract final class AppTheme {
  static final Map<TargetPlatform, ThemeData> _lightByPlatform = {};
  static final Map<TargetPlatform, ThemeData> _darkByPlatform = {};

  static ThemeData dark() => _darkByPlatform.putIfAbsent(
    defaultTargetPlatform,
    () => _fromPalette(brightness: Brightness.dark, p: AppPalette.darkPalette),
  );

  static ThemeData light() => _lightByPlatform.putIfAbsent(
    defaultTargetPlatform,
    () =>
        _fromPalette(brightness: Brightness.light, p: AppPalette.lightPalette),
  );

  static ThemeData _fromPalette({
    required Brightness brightness,
    required AppPalette p,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: brightness == Brightness.dark ? p.canvas : Colors.white,
      secondary: p.muted,
      onSecondary: p.ink,
      secondaryContainer: p.surfaceHigh,
      onSecondaryContainer: p.ink,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: p.hoverOverlay,
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
      scaffoldBackgroundColor: p.canvas,
      colorScheme: scheme.copyWith(
        surfaceContainerHighest: p.surfaceHigh,
        outline: p.border,
      ),
      fontFamily: AppTypography.family,
      fontFamilyFallback: AppTypography.fallbackForPlatform,
      textTheme: AppTypography.family == null
          ? _textTheme(p.ink, p.muted, p.inkBody)
          : _textTheme(
              p.ink,
              p.muted,
              p.inkBody,
            ).apply(fontFamily: AppTypography.family),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: p.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.popoverSurface,
        surfaceTintColor: Colors.transparent,
        barrierColor: const Color(0x66212A3A),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              elevation: 0,
              textStyle: AppTypography.control,
              overlayColor: Colors.transparent,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? p.content
                    : s.contains(WidgetState.pressed)
                    ? p.primaryPressed
                    : s.contains(WidgetState.hovered)
                    ? p.primaryHover
                    : p.primary,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? p.muted.withValues(alpha: .6)
                    : scheme.onPrimary,
              ),
              side: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.focused)
                    ? BorderSide(
                        color: p.isDark ? Colors.white : p.ink,
                        width: 1.5,
                      )
                    : BorderSide.none,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              side: BorderSide(color: p.btnBorder),
              backgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              overlayColor: Colors.transparent,
              foregroundColor: p.ink,
              textStyle: AppTypography.control,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.pressed)
                    ? p.controlPressed
                    : s.contains(WidgetState.hovered) &&
                          !s.contains(WidgetState.disabled)
                    ? p.controlHover
                    : p.surface,
              ),
              side: WidgetStateProperty.resolveWith(
                (s) => BorderSide(
                  color: s.contains(WidgetState.disabled)
                      ? p.border
                      : s.contains(WidgetState.focused)
                      ? p.focus
                      : p.btnBorder,
                ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: p.ink,
              overlayColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              textStyle: AppTypography.control,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? null
                    : s.contains(WidgetState.pressed)
                    ? p.controlPressed
                    : s.contains(WidgetState.hovered)
                    ? p.controlHover
                    : null,
              ),
              side: WidgetStateProperty.resolveWith(
                (s) => BorderSide(
                  color: s.contains(WidgetState.focused)
                      ? p.focus
                      : AppPalette.clearOf(p.focus),
                ),
              ),
            ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.ink;
            return p.muted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.surface;
            return Colors.transparent;
          }),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        side: BorderSide.none,
        backgroundColor: p.surfaceHigh,
        labelStyle: TextStyle(fontSize: 12, color: p.ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hoverColor: Colors.transparent,
        isDense: true,
        constraints: const BoxConstraints(minHeight: 40),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        hintStyle: TextStyle(color: p.muted, fontSize: 13),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.controlRim),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.controlRim),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.controlRim),
        ),
        focusedBorder: _AppFocusRingInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.focus, width: 1.2),
          haloColor: p.focus.withValues(alpha: p.isDark ? .26 : .16),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: _AppFocusRingInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.danger, width: 1.2),
          haloColor: p.danger.withValues(alpha: p.isDark ? .26 : .16),
        ),
      ),
      dividerColor: p.divider,
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(3),
        crossAxisMargin: 2,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final active =
              states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered);
          return p.muted.withValues(alpha: active ? .55 : .28);
        }),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        textColor: p.ink,
        dense: false,
        contentPadding: EdgeInsets.zero,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.15,
          color: p.ink,
        ),
        subtitleTextStyle: TextStyle(fontSize: 12, color: p.muted),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              iconSize: 20,
              foregroundColor: p.ink,
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? null
                    : s.contains(WidgetState.pressed)
                    ? p.controlPressed
                    : s.contains(WidgetState.hovered)
                    ? p.controlHover
                    : null,
              ),
              side: WidgetStateProperty.resolveWith(
                (s) => BorderSide(
                  color: s.contains(WidgetState.focused)
                      ? p.focus
                      : AppPalette.clearOf(p.focus),
                ),
              ),
            ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? p.primary
              : p.switchTrackOff;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.borderStrong,
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.popoverSurface,
        contentTextStyle: TextStyle(color: p.ink, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? p.primary.withValues(alpha: .12)
              : Colors.transparent,
        ),
      ),
      iconTheme: IconThemeData(color: p.muted, size: 20),
    );
  }

  static TextTheme _textTheme(Color ink, Color muted, Color body) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: 0,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: -0.05,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.45,
        letterSpacing: 0,
        color: body,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
        color: body,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.05,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      labelSmall: TextStyle(fontSize: 11, height: 1.35, color: muted),
    );
  }
}

class _AppFocusRingInputBorder extends OutlineInputBorder {
  const _AppFocusRingInputBorder({
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
    required this.haloColor,
  });

  final Color haloColor;

  @override
  _AppFocusRingInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
    Color? haloColor,
  }) => _AppFocusRingInputBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
    haloColor: haloColor ?? this.haloColor,
  );

  @override
  _AppFocusRingInputBorder scale(double t) => _AppFocusRingInputBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
    gapPadding: gapPadding * t,
    haloColor: haloColor,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OutlineInputBorder) {
      return _AppFocusRingInputBorder(
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        gapPadding: a.gapPadding,
        haloColor: Color.lerp(
          a is _AppFocusRingInputBorder
              ? a.haloColor
              : haloColor.withValues(alpha: 0),
          haloColor,
          t,
        )!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OutlineInputBorder) {
      return _AppFocusRingInputBorder(
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        gapPadding: b.gapPadding,
        haloColor: Color.lerp(
          haloColor,
          b is _AppFocusRingInputBorder
              ? b.haloColor
              : haloColor.withValues(alpha: 0),
          t,
        )!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (haloColor.a > 0) {
      OutlineInputBorder(
        borderSide: BorderSide(
          color: haloColor,
          width: 3.0,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        borderRadius: borderRadius,
        gapPadding: gapPadding,
      ).paint(
        canvas,
        rect,
        gapStart: gapStart,
        gapExtent: gapExtent,
        gapPercentage: gapPercentage,
        textDirection: textDirection,
      );
    }
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _AppFocusRingInputBorder &&
        super == other &&
        other.haloColor == haloColor;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, haloColor);
}
