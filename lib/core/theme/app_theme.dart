import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceHigh,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onSurface: AppColors.ink,
      outline: AppColors.borderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: scheme,
      fontFamily: 'Segoe UI',
      textTheme: _textTheme(AppColors.ink, AppColors.muted),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          backgroundColor: AppColors.primary.withValues(alpha: 0.22),
          foregroundColor: AppColors.ink,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          side: const BorderSide(color: AppColors.borderStrong),
          foregroundColor: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.content,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.ink),
        unselectedIconTheme: IconThemeData(
          color: AppColors.muted.withValues(alpha: 0.9),
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.muted),
        indicatorColor: Colors.white.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.22),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: selected ? AppColors.ink : AppColors.muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          );
        }),
      ),
      dividerColor: AppColors.border,
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.surfaceHigh;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.borderStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      surface: AppColors.surfaceLight,
      surfaceContainerHighest: const Color(0xFFE8E8ED),
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFE11D48),
      onSurface: AppColors.inkLight,
      outline: const Color(0x33000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvasLight,
      colorScheme: scheme,
      fontFamily: 'Segoe UI',
      textTheme: _textTheme(AppColors.inkLight, AppColors.mutedLight),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkLight,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0x1A000000)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.contentLight,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.15),
        height: 64,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.18),
          foregroundColor: AppColors.inkLight,
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
