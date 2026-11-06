import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  test('text, focus and primary actions retain contrast in both themes', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      final light = first > second ? first : second;
      final dark = first > second ? second : first;
      return (light + .05) / (dark + .05);
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final p = theme.brightness == Brightness.dark
          ? AppPalette.darkPalette
          : AppPalette.lightPalette;
      for (final background in [
        p.canvas,
        p.surface,
        p.content,
        p.selected,
        p.sidebar,
      ]) {
        expect(contrast(p.ink, background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.muted, background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.focus, background), greaterThanOrEqualTo(3));
      }
      expect(
        contrast(theme.colorScheme.onPrimary, p.primary),
        greaterThanOrEqualTo(4.5),
      );
      for (final action in [p.primaryHover, p.primaryPressed]) {
        expect(
          contrast(theme.colorScheme.onPrimary, action),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(p.navigationAccent, p.isDark ? p.selected : p.surface),
        greaterThanOrEqualTo(4.5),
      );
      for (final menuSelection in [
        p.selected,
        Color.alphaBlend(p.focus.withValues(alpha: .12), p.selected),
      ]) {
        expect(contrast(p.ink, menuSelection), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primary, menuSelection), greaterThanOrEqualTo(3));
      }
    }
  });

  test('dark theme uses the shared action accent, not Material purple', () {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.primary, AppPalette.darkPalette.primary);
    expect(theme.colorScheme.primary, isNot(const Color(0xFF6750A4)));
    expect(theme.scaffoldBackgroundColor, AppPalette.darkPalette.canvas);
  });

  test('light theme swaps canvas and content backgrounds', () {
    final theme = AppTheme.light();
    expect(theme.scaffoldBackgroundColor, AppPalette.lightPalette.canvas);
    expect(theme.colorScheme.surface, AppPalette.lightPalette.surface);
    expect(theme.scaffoldBackgroundColor, isNot(AppPalette.darkPalette.canvas));
  });

  test(
    'light card hover stays lighter than the muted surface (no gray melt)',
    () {
      final p = AppPalette.lightPalette;
      expect(p.cardHover, isNot(p.surfaceHigh));
      expect(
        p.cardHover.computeLuminance(),
        greaterThan(p.surfaceHigh.computeLuminance()),
      );
    },
  );
}
