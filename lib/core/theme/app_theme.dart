import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() => _fromPalette(
        brightness: Brightness.dark,
        p: AppPalette.darkPalette,
      );

  static ThemeData light() => _fromPalette(
        brightness: Brightness.light,
        p: AppPalette.lightPalette,
      );

  static ThemeData _fromPalette({
    required Brightness brightness,
    required AppPalette p,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      secondary: p.muted,
      onSecondary: p.ink,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.canvas,
      colorScheme: scheme.copyWith(
        surfaceContainerHighest: p.surfaceHigh,
        outline: p.borderStrong,
      ),
      fontFamily: 'Segoe UI',
      textTheme: _textTheme(p.ink, p.muted),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: p.borderStrong),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          side: BorderSide(color: p.borderStrong),
          foregroundColor: p.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.content,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: p.primary),
        ),
      ),
      dividerColor: p.border,
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        textColor: p.ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected) ? p.primary : p.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? p.primary.withValues(alpha: 0.35)
              : p.surfaceHigh;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.borderStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color muted) {
    return TextTheme(
      bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.57, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.54, color: muted),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      labelSmall: TextStyle(fontSize: 12, color: muted),
    );
  }
}
